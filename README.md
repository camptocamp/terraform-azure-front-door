# Architecture

This document and repository is ongoing work for proposing a solution for Azure Front Door (AFD) and origin services mainly focus -but no only- on AKS services.
The architecture of the solution is based on:

```bash

# aks examples
┌─────────┐      ┌─────────┐      ┌─────────┐
│         │  1   │         │   2  │         │
│  AFD    ├─────►│   LB    ┼─────►│  SVC    │
│         ◄──────┤         ◄──────┤         │
└─────────┘  4   └─────────┘   3  └─────────┘


# any web app
┌─────────┐      ┌───────────┐
│         │  1   │ container │
│  AFD    ├─────►│   app     │
│         ◄──────┤           │
└─────────┘  2   └───────────┘

```

## HOST_HEADER behavior matters

The different analyzed alternatives for AKS integration are based on different `domain`,`origin` and origins' `host_header` parametrization.
A few concepts which are important to understand this document:

  a. Using incoming request host name as origin_host_header

  If `origin_host_header` field is left empty, then AFD uses the incoming request host name from URL as `origin_host_header`. See [Microsoft documentation](https://learn.microsoft.com/en-us/azure/frontdoor/origin?pivots=front-door-standard-premium#origin-host-header).

  ```hcl
  host                           = "4.3.2.1"       # AKS ip
  host_header                    = null            # HOST should be injected from incoming request
  certificate_name_check_enabled = false
  supported_protocols            = ["Http"]
  ```

  Note: No TLS support after AFD.

  b. Setting HOST or HOST_HEADER explicitly

  You can set HOST or HOST_HEADER explicitly, route this origin from a specific domain, and this way implement end-to-end TLS.
  Here AFD and AKS work with different HOST and certificates.

  ```hcl
  host                           = "test-berlin-int.apps.blue.shelter-fr-dev.example.com"
  host_header                    = null
  certificate_name_check_enabled = true
  supported_protocols            = ["Https"]
  ```

  or:

  ```hcl
  host                           = "4.3.2.1"       # AKS ip
  host_header                    = "test-berlin-int.apps.blue.shelter-fr-dev.example.com"
  certificate_name_check_enabled = true
  supported_protocols            = ["Https"]
  ```

  c. Wildcard domain and certificates + load balancing done at AKS LB

  This is the recommended approach, yet this is only documented under a Bring Your Own Certificate (BYOC).
  In this solution certificates need to be synchronized between a KV towards AFD and AKS.
  Certificate syncronization significantly add too many complexities to the solution.

## Performance Notes

- If AFD origin using https, then the latency lowers around 100ms compared to http.
- If AFD origin using https, then the latency is around +100ms from what we had with other http/WAF architecture.

## Terraform module Usage

### Custom Domains and Origin Association

```hcl

domains = {
  "test.test.example.camp" = {
    cert_type = "ManagedCertificate" # ManagedCertificate or CustomerCertificate
    origin    = "aks-whoami"
  }
  "integration.berlin.test.example.camp" = {
    cert_type = "ManagedCertificate" # ManagedCertificate or CustomerCertificate
    origin    = "aks-berlin-int"
  }
  "my-non-assigned-domain.example.camp" = {
    cert_type = "ManagedCertificate" # ManagedCertificate or CustomerCertificate
    origin    = null
  }
}
```

### Origin Information to Build Origin, OriginGroup, Route, and Endpoints

#### Example 0 - Add a Container App to AFD

This is the vanilla use case.

```hcl
container-apps-whoami = {
  host                           = "whoami.ezcnbffyguc8h3g6.francecentral.azurecontainer.io" # container instance
  host_header                    = null
  certificate_name_check_enabled = false
  https_redirect_enabled         = false
  supported_protocols            = ["Http"]
  forwarding_protocol            = "HttpOnly"
  patterns_to_match              = ["/*"]
}
```

#### Example 2 - LB and HTTPS Origin

Mapping explicitly Kubernetes internal hostname to origin so we can have end-to-end TLS.
This is the most flexible integration, lowers amount of components to maintain, the KISS solution.

```hcl
aks-whoami = {
  host                           = "test.test.internal.green.shelter-fr-dev.example.com"
  host_header                    = null
  certificate_name_check_enabled = false
  https_redirect_enabled         = false
  supported_protocols            = ["Https", "Http"]
  forwarding_protocol            = "MatchRequest"
  patterns_to_match              = ["/*"]
}
```

In example above, host header is populated with the front domain as received in request, example `test.example.com`

Optionally, you can also use host_header explicitly:

```hcl
aks-berlin-int = {
  host                           = "4.3.2.1"       # AKS ip
  host_header                    = "test.test.internal.green.shelter-fr-dev.example.com"
  certificate_name_check_enabled = false
  https_redirect_enabled         = false
  supported_protocols            = ["Https", "Http"]
  forwarding_protocol            = "MatchRequest"
  patterns_to_match              = ["/*"]
}
```

#### Example 3 - AFD and LB Same Host

Both AFD and Traefik reply to front domains e.g. `test.test.example.camp`. AKS is firewalled to reply to AFD only. Requires synchronizing certificates between AFD and AKS to have end-to-end TLS.
The advantage of this solution is that we only need a single origin for the whole solution.
/!\ Certificate generation, rotation and synch seems like a lot of work here.

```hcl
any-to-aks = {
  host                           = "4.3.2.1"       # AKS ip
  host_header                    = null
  certificate_name_check_enabled = false
  https_redirect_enabled         = false
  supported_protocols            = ["Https", "Http"]
  forwarding_protocol            = "MatchRequest"
  patterns_to_match              = ["/*"]
}
```

#### Example 4 - TLS at Front Only

AFD terminates TLS, configures origins to use HTTP, Traefik load balances using `host_header`.
This is the simplest solution, yet security wise is not recommended.

```hcl
# any-to-aks = {
#   host                           = "4.3.2.1"       # AKS ip
#   host_header                    = null
#   certificate_name_check_enabled = false
#   https_redirect_enabled         = false
#   supported_protocols            = ["Http"]
#   forwarding_protocol            = "HttpOnly"
#   patterns_to_match              = ["/*"]
# }
```

### Complete example

Here a complete example for demonstration purposes, not intended for PRODUCTION

```hcl

module "frontdoor" {
  source = "git::https://github.com/camptocamp/terraform-azure-front-door.git?ref=main"

  #source = "../terra-afd"

  front_door_profile_name = "camptocampdev-afd"
  firewall_policy_name    = "myAppWafPolicy"
  dns_zone_name           = local.base_domain
  dns_zone_rg_name        = local.default_resource_group_name

  origins = {
    container-apps-whoami = {
      host                           = "whoami.ezcnbffyguc8h3g6.francecentral.azurecontainer.io" # container instance
      host_header                    = null
      certificate_name_check_enabled = false
      https_redirect_enabled         = false
      supported_protocols            = ["Http"]
      forwarding_protocol            = "HttpOnly"
      patterns_to_match              = ["/*"]
      disable_cname_creation         = false
    }
    aks-whoami = {
      host                           = "test.myapp.internal.green.shelter-fr-dev.example.com"
      host_header                    = null
      certificate_name_check_enabled = true
      https_redirect_enabled         = false
      supported_protocols            = ["Https", "Http"]
      forwarding_protocol            = "MatchRequest"
      patterns_to_match              = ["/*"]
      disable_cname_creation         = false
    }
    aks-camp-apex-redirect = {
      host                           = "test.myapp.internal.green.shelter-fr-dev.example.com"
      host_header                    = null
      certificate_name_check_enabled = true
      https_redirect_enabled         = false
      supported_protocols            = ["Https", "Http"]
      forwarding_protocol            = "MatchRequest"
      patterns_to_match              = ["/*"]
      disable_cname_creation         = false
    }
    aks-berlin-int = {
      host                           = "1.2.3.4"
      host_header                    = "test.myapp.internal.green.shelter-fr-dev.example.com"
      certificate_name_check_enabled = false
      https_redirect_enabled         = false
      supported_protocols            = ["Https", "Http"]
      forwarding_protocol            = "MatchRequest"
      patterns_to_match              = ["/*"]
      disable_cname_creation         = false
    }
  }

  domains = {
    "www.example.camp" = {
      cert_type = "ManagedCertificate"
      origin    = "aks-camp-apex-redirect"
    }
    "test.myapp.example.camp" = {
      cert_type = "ManagedCertificate"
      origin    = "aks-whoami"
    }
    "integration.berlin.myapp.example.camp" = {
      cert_type = "ManagedCertificate"
      origin    = "aks-berlin-int"
    }
    "my-non-assigned-domain.example.camp" = {
      cert_type = "ManagedCertificate"
      origin    = null
    }
  }
}

output "frontDoorEndpointHostName" {
  value = module.frontdoor.front_door_endpoint_host_name
}


output "customer_info_cnames" {
  value = module.frontdoor.customer_origins_cnames_for_domain_validation
}


output "customer_info_txt_tokens" {
  value = module.frontdoor.customer_txt_token_for_domain_validation
}


output "customer_info_token_expiration_date" {
  value = module.frontdoor.customer_txt_token_expiration_date_domain_validation
}
```

### Known issues

Origins cannot use self-signed certificates, these are not accepted by AFD
[see this post](https://learn.microsoft.com/en-us/answers/questions/5527327/frontdoor-to-origin-self-signed-certificate-for-pr)
and [this other post too](https://learn.microsoft.com/en-us/azure/frontdoor/end-to-end-tls?pivots=front-door-standard-premium#backend-tls-connection-azure-front-door-to-origin)


#### end-to-end TLS w/ Traefik

TLS subjects and Host headers do not need to match:

host: whoami.dev.shelter.camptocamp.cloud
tls config: `subject: CN=*.apps.blue.shelter-fr-dev.camptocamp.com`

for debugging it is useful to do port-forwards to traefik service
and then test with curl:

```bash 
curl -k --connect-to whoami.dev.shelter.camptocamp.cloud:443:127.0.0.1:8443 https://whoami.dev.shelter.camptocamp.cloud/ -v
* Connecting to hostname: 127.0.0.1
* Connecting to port: 8443
*   Trying 127.0.0.1:8443...
* Connected to (nil) (127.0.0.1) port 8443 (#0)
* ALPN, offering h2
* ALPN, offering http/1.1
* TLSv1.0 (OUT), TLS header, Certificate Status (22):
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
* TLSv1.2 (IN), TLS header, Certificate Status (22):
* TLSv1.3 (IN), TLS handshake, Server hello (2):
* TLSv1.2 (IN), TLS header, Finished (20):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Certificate (11):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, CERT verify (15):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Finished (20):
* TLSv1.2 (OUT), TLS header, Finished (20):
* TLSv1.3 (OUT), TLS change cipher, Change cipher spec (1):
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* TLSv1.3 (OUT), TLS handshake, Finished (20):
* SSL connection using TLSv1.3 / TLS_AES_128_GCM_SHA256
* ALPN, server accepted to use h2
* Server certificate:
*  subject: CN=*.apps.blue.shelter-fr-dev.camptocamp.com
*  start date: Jan 27 12:37:48 2026 GMT
*  expire date: Apr 27 12:37:47 2026 GMT
*  issuer: C=US; O=Let's Encrypt; CN=R13
*  SSL certificate verify result: unable to get local issuer certificate (20), continuing anyway.
* Using HTTP2, server supports multiplexing
* Connection state changed (HTTP/2 confirmed)
* Copying HTTP/2 data in stream buffer to connection buffer after upgrade: len=0
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* Using Stream ID: 1 (easy handle 0x5906a0bad9f0)
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
> GET / HTTP/2
> Host: whoami.dev.shelter.camptocamp.cloud
> user-agent: curl/7.81.0
> accept: */*
> 
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* Connection state changed (MAX_CONCURRENT_STREAMS == 250)!
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
< HTTP/2 200 
< content-type: text/plain; charset=utf-8
< date: Thu, 19 Mar 2026 09:22:37 GMT
< content-length: 444
< 
* TLSv1.2 (IN), TLS header, Supplemental data (23):
Hostname: whoami-867db88df-7w9dj
IP: 127.0.0.1
IP: ::1
IP: 10.10.33.106
IP: fe80::2c79:fbff:fe98:9e13
RemoteAddr: 10.10.32.103:34170
GET / HTTP/1.1
Host: whoami.dev.shelter.camptocamp.cloud
User-Agent: curl/7.81.0
Accept: */*
Accept-Encoding: gzip
X-Forwarded-For: 127.0.0.1
X-Forwarded-Host: whoami.dev.shelter.camptocamp.cloud
X-Forwarded-Port: 443
X-Forwarded-Proto: https
X-Forwarded-Server: traefik-gvzvk
X-Real-Ip: 127.0.0.1

* Connection #0 to host (nil) left intact
```
