# origins

resource "azurerm_cdn_frontdoor_origin_group" "this" {

  for_each = var.origins

  name                     = each.key
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
  session_affinity_enabled = false

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }

  health_probe {
    path                = "/"
    request_type        = "HEAD"
    protocol            = "Http"
    interval_in_seconds = 100
  }
}

resource "azurerm_cdn_frontdoor_origin" "this" {
  for_each = var.origins

  name                          = each.key
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.this[each.key].id

  enabled                        = true
  host_name                      = each.value.host
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = each.value.host_header != "" ? each.value.host_header : each.value.host
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = each.value.certificate_name_check_enabled
}

# routes

resource "azurerm_cdn_frontdoor_route" "this" {
  for_each = var.origins

  name                            = each.key
  cdn_frontdoor_origin_group_id   = azurerm_cdn_frontdoor_origin_group.this[each.key].id
  cdn_frontdoor_origin_ids        = [azurerm_cdn_frontdoor_origin.this[each.key].id]
  cdn_frontdoor_endpoint_id       = azurerm_cdn_frontdoor_endpoint.this[each.key].id
  cdn_frontdoor_custom_domain_ids = [for domain, values in var.domains : azurerm_cdn_frontdoor_custom_domain.this[domain].id if each.key == values["origin"]]
  cdn_frontdoor_rule_set_ids      = var.enable_cors && (var.cors_allowed_origin != "" || length(var.cors_allowed_origins) > 0) ? [azurerm_cdn_frontdoor_rule_set.cors[0].id] : []

  supported_protocols    = each.value.supported_protocols
  patterns_to_match      = each.value.patterns_to_match
  forwarding_protocol    = each.value.forwarding_protocol
  https_redirect_enabled = each.value.https_redirect_enabled
}

