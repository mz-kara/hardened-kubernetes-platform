resource "libvirt_network" "k8s" {
  name      = "k8s"
  autostart = true # le réseau redémarre avec le PC

  forward = {
    mode = "nat"
  }
  domain = {
    name = "k8s.local"
  }
  ips = [
    {
      address = "192.168.100.1"
      prefix  = 24
    }
  ]
  dns = {
    enable = "yes"
  }
}