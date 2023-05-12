variable "rules" {
  description = "specifies each object details"
  type = map(object({
    path         = string
    capabilities = list(string)
    description  = string
  }))
  default = {
    "pki" = {
      path         = "pki*",
      capabilities = ["read", "list"],
      description  = "pki policy"
    },
    "pki_sign_vntechsol_dot_local" = {
      path         = "pki/sign/vntechsol-dot-local",
      capabilities = ["create", "update"],
      description  = "pki sign policy"
    },
    "pki_issue_vntechsol_dot_local" = {
      path         = "pki/issue/vntechsol-dot-local",
      capabilities = ["create"],
      description  = "pki sign policy"
    }
  }
}

# EXTERNAL_VAULT_ADDR=$(minikube ssh "dig +short host.docker.internal" | tr -d '\r')
variable "external_vault_addr" {
  description = "get kubernetes ip"
  type        = string
  default     = "192.168.65.254"
}

# KUBE_HOST=$(kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.server}')
variable "kubernetes_host" {
  description = "specifies kubernetes-host"
  type        = string
  default     = "https://192.168.58.2:443"
}

variable "namespace" {
  description = "specifies a namespace"
  type        = string
  default     = ""
}

variable "vault_issuer" {
  description = "specifies a vault issuer name"
  type        = string
  default     = ""
}