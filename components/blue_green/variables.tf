variable "config" {
  description = "specifies object details at each layer"
  type = object({
     components = object({
       blue_green = object({
         namespaces = object({
           enabled = bool
         })
         vault = object({
           enabled = bool 
         })
       })
     })
  })
}