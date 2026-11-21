# Une ISO de configuration par nœud
resource "libvirt_cloudinit_disk" "init" {
  for_each = var.nodes

  name      = "${each.key}-cloudinit"
  user_data = file("user-data.yaml")
  meta_data = yamlencode({
    instance-id    = each.key
    local-hostname = each.key
  })
  # On code en dur les @ip de chaque noeuds ==> DHCP désactivé 
  network_config = yamlencode({
    version = 2
    ethernets = {
      primary = {
        match       = { name = "en*" }
        addresses   = ["${each.value.ip}/24"]
        routes      = [{ to = "default", via = "192.168.100.1" }]
        nameservers = { addresses = ["192.168.100.1"] }
      }
    }
  })

}

# Chaque ISO rangée dans le pool
resource "libvirt_volume" "cloudinit" {
  for_each = var.nodes

  name = "${each.key}-cloudinit.iso"
  pool = libvirt_pool.k8s.name

  target = {
    format = { type = "iso" }
  }

  create = {
    content = {
      url = libvirt_cloudinit_disk.init[each.key].path
    }
  }
}