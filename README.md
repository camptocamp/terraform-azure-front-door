# Architecture

This document and repository is ongoing work for proposing a solution for Azure Front Door (AFD) and origin services mainly focus -but no only- on AKS services.
The architecture of the solution is based on:

```bash
┌─────────┐      ┌─────────┐      ┌─────────┐
│         │  1   │         │   2  │         │
│  AFD    ├─────►│   LB    ┼─────►│  SVC    │
│         ◄──────┤         ◄──────┤         │
└─────────┘  4   └─────────┘   3  └─────────┘
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
  host                           = "4.178.158.213" # blue AKS
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
  "test.test.campto.camp" = {
    cert_type = "ManagedCertificate" # ManagedCertificate or CustomerCertificate
    origin    = "aks-whoami"
  }
  "integration.berlin.test.campto.camp" = {
    cert_type = "ManagedCertificate" # ManagedCertificate or CustomerCertificate
    origin    = "aks-berlin-int"
  }
  "my-non-assigned-domain.campto.camp" = {
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
  host                           = local.aks_shelter_fr_dev_blue_ip
  host_header                    = "test.test.internal.green.shelter-fr-dev.example.com"
  certificate_name_check_enabled = false
  https_redirect_enabled         = false
  supported_protocols            = ["Https", "Http"]
  forwarding_protocol            = "MatchRequest"
  patterns_to_match              = ["/*"]
}
```

#### Example 3 - AFD and LB Same Host

Both AFD and Traefik reply to front domains e.g. `test.test.campto.camp`. AKS is firewalled to reply to AFD only. Requires synchronizing certificates between AFD and AKS to have end-to-end TLS.
The advantage of this solution is that we only need a single origin for the whole solution.
/!\ Certificate generation, rotation and synch seems like a lot of work here.

```hcl
any-to-aks = {
  host                           = local.aks_shelter_fr_dev_blue_ip
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
#   host                           = local.aks_shelter_fr_dev_blue_ip
#   host_header                    = null
#   certificate_name_check_enabled = false
#   https_redirect_enabled         = false
#   supported_protocols            = ["Http"]
#   forwarding_protocol            = "HttpOnly"
#   patterns_to_match              = ["/*"]
# }
```
