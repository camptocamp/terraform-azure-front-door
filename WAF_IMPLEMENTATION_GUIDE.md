# WAF Implementation Guide

## What this does

The module can optionally set up a Web Application Firewall (WAF) in front of your Azure Front Door. It gives you:

- Microsoft's managed rule sets (DefaultRuleSet + BotManagerRuleSet) to catch common attacks
- Geo-filtering so you can restrict traffic by country
- A custom block page (HTTP 403) for anything the WAF rejects

Everything is behind a feature flag — nothing gets created unless you set `enable_waf = true`.

## Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_waf` | `bool` | `false` | Turns WAF on or off |
| `waf_policy_name` | `string` | `frontdoor-waf-policy` | Name for the WAF policy resource |
| `waf_mode` | `string` | `Detection` | `Detection` logs only, `Prevention` actually blocks |
| `enable_geo_filtering` | `bool` | `false` | Turns geo-filtering rules on or off |
| `allowed_countries` | `list(string)` | `[]` | Countries you want to let through — everything else gets blocked |
| `high_risk_countries` | `list(string)` | `["RU","CN","KP","IR","SY","SD","BY","VE","CU","MM"]` | Countries to always block |

## How to use it

### Just WAF, no geo-filtering

```hcl
enable_waf      = true
waf_policy_name = "my-app-waf"
waf_mode        = "Detection"
```

### WAF with geo-filtering

```hcl
enable_waf           = true
waf_mode             = "Prevention"
enable_geo_filtering = true
allowed_countries    = ["US", "CA", "GB", "FR", "DE"]
high_risk_countries  = ["RU", "CN", "KP", "IR"]
```

## What gets created

When you enable WAF, the module creates two resources:

1. **A firewall policy** (`azurerm_cdn_frontdoor_firewall_policy.waf`) containing:
   - `DefaultRuleSet` v1.0 — covers SQL injection, XSS, and other common web attacks (action set to Log)
   - `Microsoft_BotManagerRuleSet` v1.1 — detects and logs bot traffic (action set to Log)
   - A custom block response returning HTTP 403

2. **A security policy** (`azurerm_cdn_frontdoor_security_policy.waf_security_policy`) that links the firewall policy to all your custom domains on the `/*` path.

If you also turn on geo-filtering, two custom rules get added to the firewall policy:

- **HighRiskCountryRestriction** (priority 90) — blocks the countries listed in `high_risk_countries`
- **CountryRestriction** (priority 100) — blocks everything not in `allowed_countries`

The high-risk rule runs first (lower priority number = higher precedence) so those countries are always blocked, even if they somehow end up in the allow list.

## Recommended deployment steps

1. Deploy with `waf_mode = "Detection"` first. This logs what would be blocked without actually dropping any traffic.
2. Keep an eye on the WAF logs in Azure Monitor for a few days. Look for false positives — legitimate requests that the rules would have blocked.
3. Once you're happy with the results, flip to `waf_mode = "Prevention"` to start blocking for real.

## Good to know

- The WAF policy SKU is automatically set to match your Front Door profile SKU, so you don't need to worry about that.
- The security policy covers all domains defined in `var.domains`. If you only want WAF on some of them, you'll need to tweak the `domain` block in `waf.tf`.
- Country codes follow the [ISO 3166-1 alpha-2](https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2) standard. You might want to add `ZZ` to `allowed_countries` — that's the code Azure uses for IPs it can't map to any country, and leaving it out can cause false positives.
