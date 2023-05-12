
resource "kubernetes_namespace" "namespace" {
  #for_each = { for k in compact([for k, v in var.namespaces: v.enabled ? k : ""]): k => var.namespaces[k] }

  for_each = var.namespaces

  metadata {
    name = each.value.namespace_name
  }
}