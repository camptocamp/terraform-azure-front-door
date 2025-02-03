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
resource "random_string" "origin_rand" {
  for_each = var.origins

  length  = 12
  special = false
  numeric = false
  upper   = false
}

resource "azurerm_dns_cname_record" "this" {
  for_each = { for k, v in var.origins : k => v if v.disable_cname_creation != null }

  name                = "${random_string.origin_rand[each.key].result}.shelter"
  zone_name           = var.dns_zone_name
  resource_group_name = var.dns_zone_rg_name
  ttl                 = 300
  record              = azurerm_cdn_frontdoor_endpoint.this[each.key].host_name
}

# security

# externally managed firewall policies and rule sets
data "azurerm_cdn_frontdoor_firewall_policy" "this" {
  name                = var.firewall_policy_name
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_cdn_frontdoor_security_policy" "this" {

  name                     = "defaultSecurityPolicy"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = data.azurerm_cdn_frontdoor_firewall_policy.this.id
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
