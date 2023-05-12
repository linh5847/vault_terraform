# vault secrets enable pki
# vault secrets tune -max-lease-ttl=8760h pki
resource "vault_mount" "pki" {
  path        = "pki"
  type        = "pki"
  description = "This is an example PKI mount"

  default_lease_ttl_seconds = 3600
  max_lease_ttl_seconds     = 86400
}

# vault write pki/root/generate/exported common_name=vntechsol.local ttl=8760h
resource "vault_pki_secret_backend_root_cert" "root_ca" {
  depends_on            = [vault_mount.pki]
  backend               = vault_mount.pki.path
  type                  = "exported" # internal
  common_name           = "vntechsol.local"
  ttl                   = "315360000"
  format                = "pem_bundle"
  private_key_format    = "der"
  key_type              = "rsa"
  key_bits              = 4096
}

# EXTERNAL_VAULT_ADDR=$(minikube ssh "dig +short host.docker.internal" | tr -d '\r')
# external-vault service
resource "kubectl_manifest" "external_vault_endpoint" {
  depends_on = [ vault_pki_secret_backend_root_cert.root_ca ]
  yaml_body = <<YAML
apiVersion: v1
kind: Endpoints
metadata:
  name: external-vault
subsets:
  - addresses:
      - ip: "${var.external_vault_addr}"
    ports:
      - port: 8200
  YAML
}

resource "kubectl_manifest" "external_vault_service" {
  depends_on = [ vault_pki_secret_backend_root_cert.root_ca, kubectl_manifest.external_vault_endpoint ]
  yaml_body = <<YAML
apiVersion: v1
kind: Service
metadata:
  name: external-vault
  namespace: default
spec:
  ports:
  - protocol: TCP
    port: 8200
  YAML
}

# vault write pki/config/urls \
#    issuing_certificates="http://external-vault:8200/v1/pki/ca" \
#    crl_distribution_points="http://external-vault:8200/v1/pki/crl"
resource "vault_pki_secret_backend_config_urls" "vault_config_url" {
  depends_on = [ kubectl_manifest.external_vault_service ]
  backend = vault_mount.pki.path
  issuing_certificates = [
    "http://external-vault:8200/v1/pki/ca",
  ]
  crl_distribution_points = [
    "http://external-vault:8200/v1/pki/crl",
  ]
}

# Configure name that enable vntechsol.com certificate
# vault write pki/roles/vntechsol-dot-local \
#    allowed_domains=vnetchsol.local \
#    allow_subdomains=true \
#    max_ttl=72h
resource "vault_pki_secret_backend_role" "pki_role" {
  depends_on = [ vault_pki_secret_backend_config_urls.vault_config_url ]
  backend          = vault_mount.pki.path
  name             = "vntechsol-dot-local"
  ttl              = 25200
  allow_ip_sans    = true
  key_type         = "rsa"
  key_bits         = 4096
  allowed_domains  = ["vntechsol.local"]
  allow_subdomains = true
}

# vault policy write pki - <<EOF
# path "pki*"                        { capabilities = ["read", "list"] }
# path "pki/sign/example-dot-com"    { capabilities = ["create", "update"] }
# path "pki/issue/example-dot-com"   { capabilities = ["create"] }
# EOF
data "vault_policy_document" "pki_policy" {
  depends_on = [ vault_pki_secret_backend_role.pki_role ]

  dynamic "rule" {
    for_each = var.rules
    content {
      path         = rule.value["path"]
      capabilities = rule.value["capabilities"]
      description  = rule.value["description"]
    }
  }
}

resource "vault_policy" "pki_policy" {
  name   = "pki"
  policy = data.vault_policy_document.pki_policy.hcl
}

# Configure Kubernetes authentication
# kubernetes sa for vault
resource "kubernetes_manifest" "service_account_issuer" {
  depends_on = [
    vault_policy.pki_policy
  ]

  manifest = {
    apiVersion = "v1"
    kind       = "ServiceAccount"
    metadata = {
      namespace = var.namespace
      name      = var.vault_issuer

      annotations = {
        "kubernetes.io/service-account.name" = var.vault_issuer
      }
    }
    automountServiceAccountToken = true
  }
}

# ClusterRole RBAC
resource "kubernetes_cluster_role_binding" "vault_auth_role_binding" {
  depends_on = [ kubernetes_manifest.service_account_issuer ]
  metadata { 
    name = "role-tokenreview-binding" 
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "system:auth-delegator"
  }
  subject {
    kind = "ServiceAccount"
    name = var.vault_issuer
    namespace = var.namespace
  }
}

data "vault_policy_document" "reader_policy" {
  depends_on = [ kubernetes_cluster_role_binding.vault_auth_role_binding ]
  rule {
    path = "secrets/myapp/*"
    capabilities = ["read"]
    description = "allow reading secrets from myproject applications"
  }
}

resource "vault_policy" "reader_policy" {
  name = "reader"
  policy = data.vault_policy_document.reader_policy.hcl
}

resource "helm_release" "vault" {
  depends_on = [ vault_policy.reader_policy ]
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"

  namespace        = var.namespace
  create_namespace = false

  set {
    name  = "global.externalVaultAddr"
    value = "http://external-vault:8200"
  }

 # The options below are for install on VM as vault. 
 # Don't uncomment these out. 
/*
  set {
    name  = "injector.enabled"
    value = "false"
  }

  set {
    name  = "server.dev.enabled"
    value = "true"
  }

  set {
    name  = "global.tlsDisablels"
    value = "true"
  }
*/
}

resource "time_sleep" "wait_for_4m" {
  depends_on = [ 
    helm_release.vault,
  ]

  create_duration = "4m"
}

# vault auth enable kubernetes
resource "vault_auth_backend" "kubernetes" {
  depends_on = [ time_sleep.wait_for_4m ]

  type = "kubernetes"
}

resource "kubernetes_secret" "vault_auth_sa" {
  depends_on = [kubernetes_manifest.service_account_issuer, vault_auth_backend.kubernetes]
  
  metadata {
    name      = "vault-token-749nd"
    namespace = var.namespace
    annotations = {
      "kubernetes.io/service-account.name" = var.vault_issuer
    }
  }
  type = "kubernetes.io/service-account-token"
}

# kubectl run -i --image=busybox --restart=Never -t busybox
# env
# above command with env will display KUBERNETES_PORT_443_TCP_ADDR
# vault write auth/kubernetes/config \
#     token_reviewer_jwt="$TOKEN_REVIEW_JWT" \
#     kubernetes_host="$KUBE_HOST" \
#     kubernetes_ca_cert="$KUBE_CA_CERT" \
#     issuer="https://kubernetes.default.svc.cluster.local"
#
resource "vault_kubernetes_auth_backend_config" "config" {
  depends_on = [ kubernetes_manifest.service_account_issuer, vault_auth_backend.kubernetes ]
  
  backend            = vault_auth_backend.kubernetes.path
  kubernetes_host    = var.kubernetes_host
  kubernetes_ca_cert = kubernetes_secret.vault_auth_sa.data["ca.crt"]
  token_reviewer_jwt = kubernetes_secret.vault_auth_sa.data.token
  issuer             = "https://kubernetes.default.svc.cluster.local"
}

# vault write auth/kubernetes/role/issuer \
#    bound_service_account_names=issuer \
#    bound_service_account_namespaces=default \
#    policies=pki \
#    ttl=20m
resource "vault_kubernetes_auth_backend_role" "issuer_role" {
  depends_on = [ kubernetes_manifest.service_account_issuer, 
                 vault_auth_backend.kubernetes,
                 vault_kubernetes_auth_backend_config.config,
  ]

  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "issuer"
  bound_service_account_names      = [var.vault_issuer]
  bound_service_account_namespaces = ["*"] # Allow for all namespaces, try to use specific namespace here
  token_ttl = 43200 //1 day
  token_policies = [vault_policy.pki_policy.name, vault_policy.reader_policy.name]
}

# Define a certificate named
