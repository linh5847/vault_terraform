
variable "namespaces" {
  description = "specifies each object details"
  type        = map(object({
    namespace_name = string
  }))
}