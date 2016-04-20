variable "count" {}
variable "ami" {}
variable "security_groups_ids" {}
variable "key_name" {}
variable "instance_type" {}
variable "subnet_id" {}
variable "user" {}
variable "private_key_path" {}
variable "organization" {
  default = "chef_delivery"
}
