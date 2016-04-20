output "chef-server-public-ip" {
  value = "${aws_instance.chef-server.public_ip}"
}
output "chef-server-organization" {
  value = "${var.organization}"
}
output "chef-server-url" {
  value = "https://${aws_instance.chef-server.public_ip}/organizations/${var.organization}"
}
