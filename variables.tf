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
  description = "Origin information to build Origin, OriginGroup, Route, and Endpoints."
  type = map(object({
    host                           = string
    host_header                    = string
    certificate_name_check_enabled = bool
    https_redirect_enabled         = bool
    supported_protocols            = list(string)
    forwarding_protocol            = string
    patterns_to_match              = list(string)
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
    }
    aks-whoami = {
      host                           = "test.test.internal.green.shelter-fr-dev.example.com"
      host_header                    = null
      certificate_name_check_enabled = false
      https_redirect_enabled         = false
      supported_protocols            = ["Https", "Http"]
      forwarding_protocol            = "MatchRequest"
      patterns_to_match              = ["/*"]
    }
    aks-berlin-int = {
      host                           = "4.178.158.213"
      host_header                    = "test.test.internal.green.shelter-fr-dev.example.com"
      certificate_name_check_enabled = false
      https_redirect_enabled         = false
      supported_protocols            = ["Https", "Http"]
      forwarding_protocol            = "MatchRequest"
      patterns_to_match              = ["/*"]
    }
    any-to-aks = {
      host                           = "4.178.158.213"
      host_header                    = null
      certificate_name_check_enabled = false
      https_redirect_enabled         = false
      supported_protocols            = ["Https", "Http"]
      forwarding_protocol            = "MatchRequest"
      patterns_to_match              = ["/*"]
    }
  }
}

variable "firewall_policy_name" {
  description = "The name of the firewall policy to be used as data source"
  type        = string
}
