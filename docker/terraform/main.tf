provider "esxi" {
  esxi_hostname = "192.168.1.228"
  esxi_hostport = "22"
  esxi_username = "root"
  esxi_password = "h@sHiesxi"
}

resource "esxi_guest" "homelab" {
  guest_name = "${var.guest_name}"
  disk_store = "${var.disk_store}"
  memsize    = "${var.memsize}"
  numvcpus   = "4"
  power      = "on"
  notes      = "sandbox node ${var.guest_number}"

  clone_from_vm = "${var.os}-template"

  network_interfaces = [
    {
      virtual_network = "VM Network"
      nic_type        = "vmxnet3"
    },
  ]
}

resource "null_resource" "provisioner" {
  triggers {
    ip_address = "${esxi_guest.homelab.ip_address}"
  }

  connection {
    type        = "ssh"
    host        = "${esxi_guest.homelab.ip_address}"
    port        = "22"
    user        = "jray"
    private_key = "${file("~/.ssh/id_rsa.pem")}"
  }

  provisioner "file" {
    source      = "/Users/jray/hashi/terraform/esxi-sandbox/templates/bootstrap.sh"
    destination = "/tmp/bootstrap.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "echo ${var.guest_pass} | sudo -S chmod +x /tmp/bootstrap.sh",
      "sudo /tmp/bootstrap.sh",
    ]
  }
}

output "instance_ip_addr" {
  value = "${esxi_guest.homelab.ip_address}"
}
