variable "nodes" {
  description = "Nœuds du cluster et leurs caractéristiques"
  type = map(object({
    ip        = string
    vcpu      = number
    memory_mb = number
  }))
  default = {
    "k8s-master" = { ip = "192.168.100.10", vcpu = 2, memory_mb = 4096 }
    "k8s-worker" = { ip = "192.168.100.11", vcpu = 2, memory_mb = 4096 }
  }
}