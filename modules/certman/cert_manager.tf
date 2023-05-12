resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.11.0"

  create_namespace = false
  namespace        = var.namespace
  wait             = true
  wait_for_jobs    = true

  set {
    name  = "installCRDs"
    value = "true"
  }
}

resource "time_sleep" "wait_for_4m" {
  depends_on = [ 
    helm_release.cert_manager,
  ]

  create_duration = "4m"
}

# Configure an issuer and generate a certificate
