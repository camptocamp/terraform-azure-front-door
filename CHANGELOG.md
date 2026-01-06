# Changelog

## [1.1.0](https://github.com/camptocamp/terraform-azure-front-door/compare/v1.0.0...v1.1.0) (2026-01-06)


### Features

* adapt module to be used for shopinvader ([9b49783](https://github.com/camptocamp/terraform-azure-front-door/commit/9b497837e9f2b82a7bc7bb1da642f0f03d9b4113))
* add https redirection rules ([d2a191d](https://github.com/camptocamp/terraform-azure-front-door/commit/d2a191dceb2ac150b178374457d5b1c0784545d3))
* extend cors rules to be for one/multiple domains ([6fdb6b7](https://github.com/camptocamp/terraform-azure-front-door/commit/6fdb6b7203bfafa5c279da1194a900a7fd8d4779))
* remove managed waf managed rules, it requires frontdoor Premium ([d89f5ed](https://github.com/camptocamp/terraform-azure-front-door/commit/d89f5ed88124942b59b048a4873031d20775f1cc))

## 1.0.0 (2025-08-07)


### Features

* **afd:** add mvp, implements opinionated integration of domains, origins, origin groups , routes and security resources ([bfd33a9](https://github.com/camptocamp/terraform-azure-front-door/commit/bfd33a9230efea163f862291cacaca56a67dde44))
* **afd:** use  as subdomain instead of ([d706739](https://github.com/camptocamp/terraform-azure-front-door/commit/d706739e7ebbba96c621d8995ccc04940391ab97))
* **doc:** ux++ ([e5ec576](https://github.com/camptocamp/terraform-azure-front-door/commit/e5ec5765965c7879f6ca33ae4714bab94f41e1c5))
* **domain-validation:** create CNAMES automatically which are managed by c2c ([54bc34d](https://github.com/camptocamp/terraform-azure-front-door/commit/54bc34dbc648341568234426261028be2d10bee7))
* **readme:** update doc describing example of instatiation fronts for multi origin backs, using different domain and certs types ([4d3a34e](https://github.com/camptocamp/terraform-azure-front-door/commit/4d3a34ee739fb6c26decc143f106b4871b637af6))


### Bug Fixes

* **doc:** homogenization ([12ffadc](https://github.com/camptocamp/terraform-azure-front-door/commit/12ffadca43fde993708b4c5af25b0cc90c269a1a))
* **doc:** typo ([c41bc78](https://github.com/camptocamp/terraform-azure-front-door/commit/c41bc78724fd32aebd0f7a1b5017181657941798))
* **security-policy:** change default name ([e2ce7e9](https://github.com/camptocamp/terraform-azure-front-door/commit/e2ce7e90c1e3b28d8f1e53390b7ebdc0ae9c9d87))
* terraform fmt ([a0f4128](https://github.com/camptocamp/terraform-azure-front-door/commit/a0f4128ef0166a4697248e90a3796ca0a07eabef))
