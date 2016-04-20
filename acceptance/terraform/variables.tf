# Variables
variable "chef-delivery-enterprise" {
  default = "terraform"
}
variable "chef-server-organization" {
  default = "terraform"
}
variable "aws_access_key_id" {}
variable "aws_secret_access_key" {}
variable "aws_default_region" {}
variable "aws_key_pair_name" {}
variable "aws_ami_user" {
  default = "centos"
}
variable "instances" {
  default = {
    chef-server = "c3.large"
    chef-delivery = "c3.large"
    chef-build-node = "c3.large"
    chef-supermarket = "c3.large"
    chef-analytics = "c3.large"
    chef-compliance = "c3.large"
  }
}
variable "instance_counts" {
  default = {
    chef-server = 1
    chef-delivery = 1
    chef-build-node = 3
    chef-supermarket = 1
    chef-analytics = 1
    chef-compliance = 1
  }
}
variable "centos-6-amis" {
  default = {
    us-west-1 = "ami-45844401"
    us-west-2 = "ami-1255b321"
    us-east-1 = "ami-57cd8732"
    eu-west-1 = "ami-2b7f4c5c"
    eu-central-1 = "ami-2a868b37"
    ap-southeast-1 = "ami-44617116"
    ap-southeast-2 = "ami-7b81ca41"
    ap-northeast-1 = "ami-82640282"
    ap-northeast-2 = "ami-82640282"
  }
}
