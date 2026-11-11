# WAF Implementation Guide

Each entry of `waf_policies` creates a WAF policy attached only to its `domains` (keys of `var.domains`).
Policy and rule names must be letters and digits only. A domain can belong to one policy only.

```hcl
waf_policies = {
  geoEurope = {
    domains           = ["test.test.campto.camp"]
    mode              = "Prevention"                 # default: Detection
    allowed_countries = ["FR", "CH", "DE", "ZZ"]     # blocks all other countries (ZZ = unknown)

    # optional
    custom_rules = {
      BlockAdmin = {
        priority       = 200                         # geo rule uses 100
        action         = "Block"
        match_variable = "RequestUri"
        operator       = "Contains"
        match_values   = ["/admin"]
      }
    }

    # optional, Premium SKU only
    managed_rules = [
      { type = "Microsoft_DefaultRuleSet", version = "2.1", action = "Block" },
    ]
  }
}
```

Start with `mode = "Detection"`, check the WAF logs for false positives, then switch to `Prevention`.
