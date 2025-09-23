# Azure Front Door WAF Implementation Guide

This technical document provides guidance on implementing Web Application Firewall (WAF) protection for Azure Front Door using Terraform.

## Overview

The implementation provides the following security features:
- Protection against common web vulnerabilities using Microsoft's managed rule sets
- Geo-filtering to restrict access based on country of origin
- Bot protection using Microsoft's bot manager rule set
- Custom response handling for blocked requests

## Architecture

The WAF implementation consists of the following components:

1. **WAF Policy**: Azure CDN Front Door Firewall Policy that contains all rules and settings
2. **Managed Rules**: Pre-configured rule sets provided by Microsoft
3. **Custom Rules**: Custom-defined rules for geo-filtering
4. **Security Policy**: Association between the WAF policy and Front Door domains

## Implementation Steps

### 1. Create the WAF Policy

```terraform
resource "azurerm_cdn_frontdoor_firewall_policy" "waf" {
  name                              = "${var.prefix}-waf-policy"
  resource_group_name               = azurerm_resource_group.this.name
  sku_name                          = azurerm_cdn_frontdoor_profile.this.sku_name
  enabled                           = true
  mode                              = "Detection"  # Start in Detection mode, change to Prevention after testing
  custom_block_response_status_code = 403
  custom_block_response_body        = base64encode("Access denied by WAF policy.")
  
  # Additional rules will be added here
}
```

### 2. Add Microsoft's Default Rule Set

The Default Rule Set provides protection against common web vulnerabilities:

```terraform
managed_rule {
  type    = "Microsoft_DefaultRuleSet"  # Microsoft's managed rule set
  version = "2.1"                       # Use the latest version
  action  = "Log"                       # Global action for the rule set
  
  # Optional: Override specific rules
  override {
    rule_group_name = "XSS"             # Cross-Site Scripting protection group
    rule {
      rule_id = "942150"                # Specific rule ID
      enabled = true
      action  = "Log"                   # Set to "Log" for monitoring without blocking
    }
    # Additional rule overrides...
  }
}
```

### 3. Add Bot Protection

Add Microsoft's Bot Manager rule set to protect against automated bots:

```terraform
managed_rule {
  type    = "Microsoft_BotManagerRuleSet"  # Bot protection rule set
  version = "1.0"
  action  = "Log"                          # Log bot activity without blocking
}
```

### 4. Add Geo-Filtering Rule

Create a custom rule for geo-filtering to restrict access by country:

```terraform
custom_rule {
  name     = "CountryRestriction"
  enabled  = true
  priority = 100                      # Lower numbers have higher priority
  type     = "MatchRule"
  action   = "Block"                  # Block requests that match this rule
  
  match_condition {
    match_variable     = "RemoteAddr"
    operator           = "GeoMatch"
    negation_condition = true         # true = block countries NOT in the list
    match_values       = [            # List of country codes to allow
      "US", "CA", "GB", "FR", "DE", "ES", "IT", "NL", "BE", "CH"
      # Add more country codes as needed
    ]
  }
}
```

### 5. Associate WAF Policy with Front Door

Create a security policy to associate the WAF policy with Front Door domains:

```terraform
resource "azurerm_cdn_frontdoor_security_policy" "waf_security_policy" {
  name                     = "${var.prefix}-security-policy"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
  
  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.waf.id
      
      association {
        patterns_to_match = ["/*"]    # Apply to all paths
        
        # Associate with all domains
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_custom_domain.example.id
        }
        # Add more domains as needed
      }
    }
  }
}
```

## Configuration Parameters

The WAF implementation uses the following variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `enable_waf` | Whether to enable WAF | `false` |
| `waf_policy_name` | Name of the WAF policy | `frontdoor-waf-policy` |
| `waf_mode` | WAF mode (Detection or Prevention) | `Detection` |
| `enable_geo_filtering` | Whether to enable geo-filtering | `false` |
| `allowed_countries` | List of allowed country codes | List of common countries |

## Testing and Deployment

1. **Initial Deployment**:
   - Deploy the WAF in "Detection" mode first
   - This logs potential threats without blocking them
   - Review logs to identify false positives

2. **Monitoring**:
   - Monitor WAF logs in Azure Monitor
   - Look for patterns of blocked requests and potential false positives

3. **Production Deployment**:
   - After validating detection mode, change to "Prevention" mode
   - Update the `waf_mode` variable to "Prevention"
   - This will actively block identified threats

## Rule Customization

### Common Rule Overrides

These are common rules you might want to override based on your application needs:

1. **XSS Protection Rules**:
   - 941100: XSS using script tag
   - 942150: SQL Injection attempt

2. **Protocol Attack Rules**:
   - 921110: HTTP Protocol Violation

3. **PHP Rules**:
   - 933100: PHP Injection Attack

## Troubleshooting

1. **High Rate of Blocked Requests**:
   - Check for false positives in WAF logs
   - Consider overriding specific rules causing issues
   - Switch back to Detection mode temporarily

2. **Legitimate Users Blocked by Geo-Filtering**:
   - Add missing country codes to the `allowed_countries` list
   - Consider using a VPN allow list instead if granular control is needed

3. **Performance Issues**:
   - Review the WAF logs for processing time
   - Consider optimizing custom rules and reducing complexity

## Best Practices

1. **Start in Detection Mode**:
   - Always start with WAF in Detection mode
   - Analyze logs before switching to Prevention mode

2. **Regular Rule Reviews**:
   - Periodically review WAF logs for false positives
   - Update rule configurations as needed

3. **Layered Security**:
   - WAF is one part of a defense-in-depth strategy
   - Combine with secure coding practices and other security measures

4. **Update Rule Versions**:
   - Periodically check for updates to managed rule sets
   - Update to the latest version to get protection against new threats
