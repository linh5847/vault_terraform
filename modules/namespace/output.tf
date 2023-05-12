output "namespace" {
  value = values(kubernetes_namespace.namespace)[*].metadata[0].name
}