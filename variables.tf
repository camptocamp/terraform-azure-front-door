variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
  default     = "frontdoor-rg"
}

variable "resource_group_location" {
  description = "The location of the resource group"
  type        = string
  default     = "France Central"

}

variable "front_door_sku_name" {
  description = "The SKU name of the Front Door"
  type        = string
  default     = "Premium_AzureFrontDoor"
}

variable "front_door_profile_name" {
  description = "The name of the front door profile."
  type        = string
  default     = "exampledev-afd"
}

variable "domains" {
  description = "Custom domains and their origin association."
  type = map(object({
    cert_type = string
    origin    = string
  }))

  default = {
    "test.test.campto.camp" = {
      cert_type = "ManagedCertificate"
      origin    = "aks-whoami"
    }
    "integration.berlin.test.campto.camp" = {
      cert_type = "ManagedCertificate"
      origin    = "aks-berlin-int"
    }
    "my-non-assigned-domain.campto.camp" = {
      cert_type = "ManagedCertificate"
      origin    = null
    }
  }
}

variable "origins" {
  description = "Origin information to build Origin, OriginGroup, Route, and Endpoints. Set host_header to an empty string if you want to use the same value as host automatically."
  type = map(object({
    host                           = string
    host_header                    = string
    certificate_name_check_enabled = bool
    https_redirect_enabled         = bool
    supported_protocols            = list(string)
    forwarding_protocol            = string
    patterns_to_match              = list(string)
    disable_cname_creation         = bool
  }))
  default = {
    container-apps-whoami = {
      host                           = "whoami.ezcnbffyguc8h3g6.francecentral.azurecontainer.io"
      host_header                    = null
      certificate_name_check_enabled = false
      https_redirect_enabled         = false
      supported_protocols            = ["Http"]
      forwarding_protocol            = "HttpOnly"
      patterns_to_match              = ["/*"]
      disable_cname_creation         = false
    }
    aks-whoami = {
      host                           = "test.test.internal.green.shelter-fr-dev.example.com"
      host_header                    = null
      certificate_name_check_enabled = false
      https_redirect_enabled         = false
      supported_protocols            = ["Https", "Http"]
      forwarding_protocol            = "MatchRequest"
      patterns_to_match              = ["/*"]
      disable_cname_creation         = false
    }
    aks-berlin-int = {
      host                           = "4.178.158.213"
      host_header                    = "test.test.internal.green.shelter-fr-dev.example.com"
      certificate_name_check_enabled = false
      https_redirect_enabled         = false
      supported_protocols            = ["Https", "Http"]
      forwarding_protocol            = "MatchRequest"
      patterns_to_match              = ["/*"]
      disable_cname_creation         = false
    }
    any-to-aks = {
      host                           = "4.178.158.213"
      host_header                    = null
      certificate_name_check_enabled = false
      https_redirect_enabled         = false
      supported_protocols            = ["Https", "Http"]
      forwarding_protocol            = "MatchRequest"
      patterns_to_match              = ["/*"]
      disable_cname_creation         = false
    }
  }
}

variable "firewall_policy_name" {
  description = "The name of the firewall policy to be used as data source. Set to null to disable the firewall policy."
  type        = string
  default     = null
}

variable "enable_cors" {
  description = "Whether to enable CORS for the Front Door. If true, a CORS rule set will be created."
  type        = bool
  default     = false
}

variable "cors_allowed_origins" {
  description = "List of origins to allow for CORS. These will be used in the CORS rules."
  type        = list(string)
  default     = []
}

variable "cors_allowed_origin" {
  description = "The origin to allow for CORS. This will be used in the CORS rule. Deprecated: Use cors_allowed_origins instead."
  type        = string
  default     = ""
}

variable "dns_zone_name" {
  description = "The name of the DNS zone where to create CNAME for customer communication when domain validation is needed. Set to null or empty string to disable global DNS zone management."
  type        = string
  default     = null
}

variable "dns_zone_rg_name" {
  description = "The name of the resource group for the DNS zone. Required only if dns_zone_name is set."
  type        = string
  default     = null
}

variable "enable_waf" {
  description = "Whether to enable Web Application Firewall (WAF) for the Front Door."
  type        = bool
  default     = false
}

variable "waf_policy_name" {
  description = "The name of the WAF policy to create. Only used if enable_waf is true."
  type        = string
  default     = "frontdoor-waf-policy"
}

variable "waf_mode" {
  description = "The WAF mode. Can be 'Detection' or 'Prevention'."
  type        = string
  default     = "Detection"
  validation {
    condition     = contains(["Detection", "Prevention"], var.waf_mode)
    error_message = "The WAF mode must be either 'Detection' or 'Prevention'."
  }
}

variable "allowed_countries" {
  description = "List of allowed country codes. If empty, all countries are allowed. 'ZZ' is included to avoid false positives for IPs not mapped to any country."
  type        = list(string)
  default     = []
}

variable "high_risk_countries" {
  description = "List of high-risk country codes known by Azure that should be explicitly blocked."
  type        = list(string)
  default = [
    "RU", "CN", "KP", "IR", "SY", "SD", "BY", "VE", "CU", "MM"
  ]
}

variable "enable_geo_filtering" {
  description = "Whether to enable geo-filtering for the Front Door."
  type        = bool
  default     = false
}
