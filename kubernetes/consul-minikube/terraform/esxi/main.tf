provider "esxi" {
  esxi_hostname = ""
  esxi_hostport = "22"
  esxi_username = "root"
  esxi_password = ""
}

resource "esxi_guest" "homelab" {
  guest_name = "${var.guest_name}"
  disk_store = "${var.disk_store}"
  memsize    = "${var.memsize}"
  numvcpus   = "4"
  power      = "on"
  notes      = "consul minikube node ${var.guest_number}"

  clone_from_vm = "${var.os}-template"

  network_interfaces = {
    virtual_network = "VM Network"
    nic_type        = "vmxnet3"
  }

  provisioner "remote-exec" {
    command = <<EOF
  cd ~/
  curl -O https://github.com/raygj/consul-content/blob/master/kubernetes/consul-minikube/terraform/aws/files/bootstrap.sh
  chmod +x ~/bootstrap.sh
  EOF
  }
}

#  provisioner "file" {
#    source      = "/templates/bootstrap.sh"
#    destination = "/tmp/bootstrap.sh"
#  }

#  provisioner "remote-exec" {
#    inline = [
#      "chmod +x /tmp/bootstrap.sh",
#      "sudo ./tmp/bootstrap.sh",
#    ]
#  }

#  connection {
#    type        = "ssh"
#    private_key = "${file("~/.ssh/id_rsa")}"
#    user    = "jray"
#    host    = "192.168.1.87"
#    timeout = "30s"
#  }
#}

output "instance_ips" {
  value = ["${esxi_guest.homelab.*.ip_address}"]
}
