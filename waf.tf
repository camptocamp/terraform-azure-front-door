# Web Application Firewall (WAF) Configuration

# Create WAF policy
resource "azurerm_cdn_frontdoor_firewall_policy" "waf" {
  count = var.enable_waf ? 1 : 0

  name                              = var.waf_policy_name
  resource_group_name               = azurerm_resource_group.this.name
  sku_name                          = azurerm_cdn_frontdoor_profile.this.sku_name
  enabled                           = true
  mode                              = var.waf_mode
  custom_block_response_status_code = 403
  custom_block_response_body        = base64encode("Access denied by WAF policy.")

  # Add Microsoft's default rule set (equivalent to AWS's CommonRuleSet)
  managed_rule {
    type    = "Microsoft_DefaultRuleSet"
    version = "2.1"
    action  = "Log"

    # Override specific rules to set them to "Log" mode (equivalent to AWS's "Count")
    override {
      rule_group_name = "XSS"
      rule {
        rule_id = "942150"
        enabled = true
        action  = "Log"
      }
      rule {
        rule_id = "941100"
        enabled = true
        action  = "Log"
      }
    }

    override {
      rule_group_name = "PROTOCOL-ATTACK"
      rule {
        rule_id = "921110"
        enabled = true
        action  = "Log"
      }
    }
  }

  # Add Microsoft's bot protection rule set
  managed_rule {
    type    = "Microsoft_BotManagerRuleSet"
    version = "1.0"
    action  = "Log"
  }

  # Geo-filtering custom rule (equivalent to your ShopinvaderCountryRestric)
  dynamic "custom_rule" {
    for_each = var.enable_geo_filtering ? [1] : []
    content {
      name     = "CountryRestriction"
      enabled  = true
      priority = 100
      type     = "MatchRule"
      action   = "Block"

      match_condition {
        match_variable     = "RemoteAddr"
        operator           = "GeoMatch"
        negation_condition = true
        match_values       = var.allowed_countries
      }
    }
  }
}

# Associate WAF policy with Front Door security policy
resource "azurerm_cdn_frontdoor_security_policy" "waf_security_policy" {
  count = var.enable_waf ? 1 : 0

  name                     = "${var.waf_policy_name}-security-policy"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.waf[0].id

      association {
        patterns_to_match = ["/*"]

        dynamic "domain" {
          for_each = var.domains
          content {
            cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_custom_domain.this[domain.key].id
          }
        }
      }
    }
  }
}
