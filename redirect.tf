# URL Redirection Rule Set
resource "azurerm_cdn_frontdoor_rule_set" "redirect" {
  count = var.enable_url_redirect && length(var.redirect_rules) > 0 ? 1 : 0

  name                     = "URLRedirection"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
}

# URL Redirection Rules
resource "azurerm_cdn_frontdoor_rule" "url_redirect" {
  for_each = var.enable_url_redirect ? var.redirect_rules : {}

  name                      = each.key
  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.redirect[0].id
  order                     = 1
  behavior_on_match         = "Continue"

  conditions {
    host_name_condition {
      operator         = "Equal"
      negate_condition = false
      match_values     = [each.value.source_host]
    }
  }

  actions {
    url_redirect_action {
      redirect_type        = each.value.redirect_type
      destination_hostname = each.value.destination_host
      redirect_protocol    = "Https"
      destination_path     = each.value.preserve_path ? "" : "/"
      query_string         = each.value.preserve_query ? "" : ""
      destination_fragment = ""
    }
  }
}
