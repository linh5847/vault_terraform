module "namespace" {
  source = "../../modules/namespace"

  count = var.config.components.blue_green.namespaces.enabled ? 1 : 0

  namespaces = {
    vault = {
      namespace_name = "vault"
    },
    cert-manager = {
      namespace_name = "cert-manager"
    },
    traefik = {
      namespace_name = "traefik"
    }
  }
}