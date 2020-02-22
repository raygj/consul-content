# for use with Terraform CLI or as source for Terraform Cloud
# private_key is either a file or the key is written to Terraform Cloud as a sensitive variable
variable "aws_region" {
  description = "target region"
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "vpc cidr block"
  default     = "172.16.0.0/16"
}

variable "owner" {
  description = "human name"
  default     = "jray"
}

variable "ttl" {
  description = "ttl in hours for reaper bot, -1 is infinte"
  default     = "12"
}

variable "instance_type" {
  description = "EC2 machine size"
  default     = "t2.medium" // 2 vCPU and 4G RAM
}

variable "ami_id" {
  description = "AMI to be used, default is Ubuntu 18.04 LTS EBS SSD" // https://cloud-images.ubuntu.com/locator/ec2
  default     = "ami-0959e8feedaf156bf"
}

variable "key_name" {
  description = "EC2 private key"
  default     = "jray"
}

variable "private_key" {
  description = "full private key stored as secure variable in TFC/E"
}

variable "ssh_user" {
  description = "EC2 user - will depend on OS"
  default     = "ubuntu"
}
