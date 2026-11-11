# WAF: one policy per entry in var.waf_policies, attached only to its domains.

resource "azurerm_cdn_frontdoor_firewall_policy" "this" {
  for_each = var.waf_policies

  name                = each.key
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = azurerm_cdn_frontdoor_profile.this.sku_name
  mode                = each.value.mode

  # Geo-filtering: block countries not in allowed_countries
  dynamic "custom_rule" {
    for_each = length(each.value.allowed_countries) > 0 ? [1] : []
    content {
      name     = "AllowedCountries"
      priority = 100
      type     = "MatchRule"
      action   = "Block"

      match_condition {
        match_variable     = "RemoteAddr"
        operator           = "GeoMatch"
        negation_condition = true
        match_values       = each.value.allowed_countries
      }
    }
  }

  dynamic "custom_rule" {
    for_each = each.value.custom_rules
    content {
      name     = custom_rule.key
      priority = custom_rule.value.priority
      type     = "MatchRule"
      action   = custom_rule.value.action

      match_condition {
        match_variable = custom_rule.value.match_variable
        operator       = custom_rule.value.operator
        match_values   = custom_rule.value.match_values
      }
    }
  }

  dynamic "managed_rule" {
    for_each = each.value.managed_rules
    content {
      type    = managed_rule.value.type
      version = managed_rule.value.version
      action  = managed_rule.value.action
    }
  }
}

resource "azurerm_cdn_frontdoor_security_policy" "waf" {
  for_each = var.waf_policies

  name                     = "${each.key}-security-policy"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.this[each.key].id

      association {
        patterns_to_match = ["/*"]

        dynamic "domain" {
          for_each = toset(each.value.domains)
          content {
            cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_custom_domain.this[domain.value].id
          }
        }
      }
    }
  }
}
