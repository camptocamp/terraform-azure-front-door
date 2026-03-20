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
resource "azurerm_cdn_frontdoor_endpoint" "this" {

  for_each = var.origins

  name                     = each.key
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id

}


moved {
  from = azurerm_dns_cname_record.this
  to   = azurerm_dns_cname_record.camptocamp_cloud_cannonical_names
}


locals {
  camptocamp_cloud_cannonical_names = {
    for k, v in var.domains : k => v
    if v.origin != null && var.dns_zone_name != null && endswith(k, var.dns_zone_name)
  }
}
######################################################################
# Cannonical CNAMES: <project-instance>.shelter.camptocamp.cloud
#
# these are used for customer communication
# azure endpoints names should not be comunicated to customers
resource "azurerm_dns_cname_record" "camptocamp_cloud_cannonical_names" {

  for_each = local.camptocamp_cloud_cannonical_names

  name                = replace(each.key, ".${var.dns_zone_name}", "")
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
  count = var.enable_cors && length(var.cors_allowed_origins) > 0 ? 1 : 0

  name                     = "CORS"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
}



# Unified CORS rules for both single and multiple origins
resource "azurerm_cdn_frontdoor_rule" "cors_origins" {
  for_each = var.enable_cors ? toset(var.cors_allowed_origins) : []

  name                      = "corsorigin${index(var.cors_allowed_origins, each.value)}"
  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.cors[0].id
  order                     = 100 + length(each.value) + index(sort(var.cors_allowed_origins), each.value) * 10
  behavior_on_match         = "Continue"

  # Condition
  conditions {
    request_header_condition {
      header_name      = "Origin"
      operator         = "Equal"
      match_values     = [each.value]
      transforms       = []
      negate_condition = false
    }
  }

  # Action
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
