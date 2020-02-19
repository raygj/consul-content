# Terraform 0.12 compliant
# connection
provider "aws" {
  region = var.aws_region
}

# network
resource "aws_vpc" "test-env" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_eip" "ip-test-env" {
  instance = aws_instance.test-ec2-instance.id
  vpc      = true
}

# subnets
resource "aws_subnet" "subnet-uno" {
  cidr_block        = cidrsubnet(aws_vpc.test-env.cidr_block, 3, 1)
  vpc_id            = aws_vpc.test-env.id
  availability_zone = "us-east-1a"
}

# gateways
resource "aws_internet_gateway" "test-env-gw" {
  vpc_id = aws_vpc.test-env.id
}

# subnets
resource "aws_route_table" "route-table-test-env" {
  vpc_id = aws_vpc.test-env.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test-env-gw.id
  }
}

resource "aws_route_table_association" "subnet-association" {
  subnet_id      = aws_subnet.subnet-uno.id
  route_table_id = aws_route_table.route-table-test-env.id
}

# security
resource "aws_security_group" "ingress-all-test" {
  name   = "allow-all-sg"
  vpc_id = aws_vpc.test-env.id

  ingress {
    cidr_blocks = [
      "0.0.0.0/0",
    ]

    from_port = 22
    to_port   = 22
    protocol  = "tcp"
  }

  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC server
resource "aws_instance" "test-ec2-instance" {
  ami             = var.ami_id
  instance_type   = var.instance_type
  key_name        = var.key_name
  vpc_security_group_ids = [aws_security_group.ingress-all-test.id]

  tags = {
    Name  = "${var.owner}-demo_env"
    owner = var.owner
    TTL   = var.ttl
  }

  # provisioner "file" {
  #   source      = "/files/*"
  #   destination = "/tmp"
  # }

  # provisioner "remote-exec" {
  #   inline = [
  #     "chmod +x /tmp/bootstrap.sh",
  #     "sudo ./tmp/bootstrap.sh",
  #   ]
  # }

  # connection {
  #   type        = "ssh"
  #   private_key = var.private_key
  #   # private_key = "~/.ssh/id_rsa"
  #   #   private_key = "${file("$var.private_key")}"
  #   user    = "ubuntu"
  #   host    = "aws_instance.test-ec2-instance.public_ip"
  #   timeout = "30s"
  # }
}

