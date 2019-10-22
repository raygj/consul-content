variable "guest_name" {
  description = "full name of VM"
}

variable "disk_store" {
  description = "SSD or SATA"
}

variable "memsize" {
  description = "amount of RAM in GB"
}

variable "guest_number" {
  description = "used in notes field, should match guest name"
}

variable "os" {
  description = "centos7 or ubuntu, used to pick template"
}

variable "guest_pass" {
  description = "password used for sudo"
}
