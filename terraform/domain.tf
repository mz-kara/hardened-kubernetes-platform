# Une VM par nœud du cluster
resource "libvirt_domain" "node" {
  for_each = var.nodes

  name        = each.key
  type        = "kvm"
  vcpu        = each.value.vcpu
  memory      = each.value.memory_mb
  memory_unit = "MiB"
  running     = true

  # Le processeur de l'hôte est présenté tel quel à la VM
  cpu = {
    mode = "host-passthrough"
  }

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
    boot_devices = [{ dev = "hd" }]
  }

  devices = {
    disks = [
      # Disque système du nœud
      {
        source = {
          file = { file = libvirt_volume.disk[each.key].path }
        }
        target = { dev = "vda", bus = "virtio" }
        driver = { name = "qemu", type = "qcow2" }
      },
      # ISO cloud-init, branchée comme un CD-ROM
      {
        device = "cdrom"
        source = {
          file = { file = libvirt_volume.cloudinit[each.key].path }
        }
        target = { dev = "sda", bus = "sata" }
        driver = { name = "qemu", type = "raw" }
      },
    ]

    # Carte réseau branchée sur le réseau du cluster
    interfaces = [
      {
        model = { type = "virtio" }
        source = {
          network = { network = libvirt_network.k8s.name }
        }
      },
    ]

    # Console série : virsh console <nom>
    consoles = [
      {
        target = { type = "serial", port = 0 }
      },
    ]
  }
}