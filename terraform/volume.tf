resource "libvirt_volume" "ubuntu_base" {
  name = "ubuntu-24.04.qcow2"
  pool = libvirt_pool.k8s.name
  target = {
    format = {
      type        = "qcow2"
      permissions = { mode = "0644" }
    }
  }

  create = {
    content = {
      url = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
    }
  }
}

resource "libvirt_volume" "disk" {
  for_each = var.nodes

  name     = "${each.key}.qcow2"
  pool     = libvirt_pool.k8s.name
  capacity = 20 * 1024 * 1024 * 1024

  target = {
    format = {
      type = "qcow2"
    }
  }

  backing_store = {
    path = libvirt_volume.ubuntu_base.path
    format = {
      type = "qcow2"
    }
  }
}
