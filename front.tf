# afd

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

resource "azurerm_cdn_frontdoor_profile" "this" {
  name                = var.front_door_profile_name
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = var.front_door_sku_name
}

# domains

resource "azurerm_cdn_frontdoor_custom_domain" "this" {
  for_each = var.domains

  name                     = replace(each.key, ".", "-")
  host_name                = each.key
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id

  tls {
    certificate_type = each.value.cert_type
  }
}

resource "azurerm_cdn_frontdoor_custom_domain_association" "this" {
  for_each = { for k, v in var.domains : k => v if v.origin != null }

  cdn_frontdoor_custom_domain_id = azurerm_cdn_frontdoor_custom_domain.this[each.key].id
  cdn_frontdoor_route_ids        = [azurerm_cdn_frontdoor_route.this[each.value.origin].id]
}

# endpoints

resource "random_id" "front_door_endpoint_random" {
  for_each = var.origins

  byte_length = 8
}

resource "azurerm_cdn_frontdoor_endpoint" "this" {

  for_each = var.origins

  name                     = each.key
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id

  tags = {
    ENV = "dev"
  }
}

# CNAME for customer communication
locals {
  # Create a map of origins to their associated domains
  origin_domain_map = { for domain_key, domain in var.domains :
    domain.origin => domain_key... if domain.origin != null
  }
}

resource "azurerm_dns_cname_record" "this" {
  for_each = { for k, v in var.origins : k => v if v.disable_cname_creation == false && var.dns_zone_name != null && var.dns_zone_name != "" }

  name = (
    # Check if the origin has any domain associated with it
    contains(keys(local.origin_domain_map), each.key)
    ?
    # If yes, take the first part of the first domain (before the first dot)
    split(".", element(local.origin_domain_map[each.key], 0))[0]
    :
    # If no domain is associated, use the origin name with "-afd" suffix
    "${each.key}-afd"
  )
  zone_name           = var.dns_zone_name
  resource_group_name = var.dns_zone_rg_name
  ttl                 = 300
  record              = azurerm_cdn_frontdoor_endpoint.this[each.key].host_name
}

# security

# externally managed firewall policies and rule sets
data "azurerm_cdn_frontdoor_firewall_policy" "this" {
  count = var.firewall_policy_name != null ? 1 : 0

  name                = var.firewall_policy_name
  resource_group_name = azurerm_resource_group.this.name
}

# Rule Sets
resource "azurerm_cdn_frontdoor_rule_set" "cors" {
  count = length(var.cors_allowed_origins) > 0 ? 1 : 0

  name                     = "CORS"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
}



# CORS rules - one rule per allowed origin
resource "azurerm_cdn_frontdoor_rule" "cors" {
  for_each = toset(var.cors_allowed_origins)

  name                      = "cors${substr(md5(each.value), 0, 8)}"
  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.cors[0].id
  order                     = 100
  behavior_on_match         = "Continue"

  conditions {
    request_header_condition {
      header_name  = "Origin"
      operator     = "Equal"
      match_values = [each.value]
    }
  }

  actions {
    response_header_action {
      header_action = "Overwrite"
      header_name   = "Access-Control-Allow-Origin"
      value         = each.value
    }
  }
}

resource "azurerm_cdn_frontdoor_security_policy" "this" {
  count = var.firewall_policy_name != null ? 1 : 0

  name                     = "defaultSecurityPolicy"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = data.azurerm_cdn_frontdoor_firewall_policy.this[0].id
      association {

        dynamic "domain" {
          for_each = var.domains
          content {
            cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_custom_domain.this[domain.key].id
          }
        }
        patterns_to_match = ["/*"]
      }
    }
  }
}
