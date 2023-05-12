module "vault" {
  depends_on = [ module.namespace ]
  source     = "../../modules/vault"
  count      = var.config.components.blue_green.vault.enabled ? 1 : 0

  # in your environment maybe 0 or 1. Tries the terraform plan first and works out
  namespace    = module.namespace[0].namespace[2] 
  vault_issuer = "vault-issuer"
}