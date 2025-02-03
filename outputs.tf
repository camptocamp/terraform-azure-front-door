output "front_door_endpoint_host_name" {
  value = azurerm_cdn_frontdoor_endpoint.this[*]
}

output "customer_origins_cnames_for_domain_validation" {
  value = { for k, v in var.origins : k => azurerm_dns_cname_record.this[k].fqdn if v.disable_cname_creation != null }
}

output "customer_txt_token_for_domain_validation" {
  value = { for k, v in var.domains : k => azurerm_cdn_frontdoor_custom_domain.this[k].validation_token}
}

output "customer_txt_token_expiration_date_domain_validation" {
  value = { for k, v in var.domains : k => azurerm_cdn_frontdoor_custom_domain.this[k].expiration_date}
}
