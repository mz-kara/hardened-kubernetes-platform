resource "libvirt_pool" "k8s" {
  name = "k8s-pool"
  type = "dir"

  target = {
    path = "/var/lib/libvirt/images/k8s"
  }

  create = {
    build     = true # crée le dossier s'il n'existe pas
    start     = true # active le pool
    autostart = true # le réactive au démarrage du PC
  }
}