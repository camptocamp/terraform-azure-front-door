output "front_door_endpoint_host_names" {
  description = "The host names of the Front Door endpoints"
  value       = { for k, v in azurerm_cdn_frontdoor_endpoint.this : k => v.host_name }
}

output "customer_origins_cnames_for_domain_validation" {
  description = "CNAME records for domain validation, empty if no CNAME records are created"
  value = length(azurerm_dns_cname_record.this) > 0 ? {
    for k, v in azurerm_dns_cname_record.this : k => v.fqdn
  } : {}
}

output "customer_txt_token_for_domain_validation" {
  description = "TXT token values for domain validation"
  value       = { for k, v in var.domains : k => azurerm_cdn_frontdoor_custom_domain.this[k].validation_token }
}

output "customer_txt_token_expiration_date_domain_validation" {
  description = "Expiration dates for domain validation tokens"
  value       = { for k, v in var.domains : k => azurerm_cdn_frontdoor_custom_domain.this[k].expiration_date }
}

output "frontdoor_profile_id" {
  description = "The ID of the Front Door profile"
  value       = azurerm_cdn_frontdoor_profile.this.id
}

output "frontdoor_resource_group_name" {
  description = "The name of the resource group containing the Front Door profile"
  value       = azurerm_resource_group.this.name
}

output "cors_rule_set_id" {
  description = "The ID of the CORS rule set"
  value       = var.enable_cors && (var.cors_allowed_origin != "" || length(var.cors_allowed_origins) > 0) ? azurerm_cdn_frontdoor_rule_set.cors[0].id : null
}

output "waf_policy_id" {
  description = "The ID of the WAF policy"
  value       = var.enable_waf ? azurerm_cdn_frontdoor_firewall_policy.waf[0].id : null
}

output "waf_security_policy_id" {
  description = "The ID of the WAF security policy"
  value       = var.enable_waf ? azurerm_cdn_frontdoor_security_policy.waf_security_policy[0].id : null
}
