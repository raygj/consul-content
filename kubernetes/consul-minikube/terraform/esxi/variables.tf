variable "guest_name" {
  description = "full name of VM"
}

variable "disk_store" {
  description = "SSD or SATA"
  default     = "SSD"
}

variable "memsize" {
  description = "amount of RAM in GB"
  default     = "4096"
}

variable "guest_number" {
  description = "used in notes field, should match guest name"
  default     = "0"
}

variable "os" {
  description = "centos7 or ubuntu, used to pick template"
  default     = "ubuntu"
}

#variable "private_key" {
#  description = "path to SSH key that Terraform remote-exec should use"
#  default     = "~/.ssh/id_rsa"
#}

