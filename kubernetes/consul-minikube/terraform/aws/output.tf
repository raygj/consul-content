output "elastic_IP_address" {
  value = ["${aws_eip.ip-test-env.public_ip}"]
}
