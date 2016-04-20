#
# Delivery Cluster with Terraform
#
provider "aws" {
  access_key = "${var.aws_access_key_id}"
  secret_key = "${var.aws_secret_access_key}"
  region = "${var.aws_default_region}"
}

# Networking Configuration
# module "ec2-network" {
#  source = "./ec2-network"
# }

# Setup Chef Server
module "chef-server" {
  source = "./chef-server"
  ami = "${lookup(var.centos-6-amis, var.aws_default_region)}"
  count = "${lookup(var.instance_counts, "chef-server")}"
  instance_type = "${lookup(var.instances, "chef-server")}"
#  subnet_id = "${module.ec2-network.subnet_id}"
#  security_groups_ids = "${module.ec2-network.chef-server_security_group_id}"
  key_name = "${var.aws_key_pair_name}"
  user = "${var.aws_ami_user}"
  private_key_path = ".keys/${var.aws_key_pair_name}.pem"

  organization = "${var.chef-server-organization}"
}

# Setup Chef Build-Node(s) - To be push client node
# module "chef_delivery_build_node" {
#  source                  = "github.com/chef/tf_chef_delivery_build_node"
#  aws_ami_id              = "${lookup(var.centos-6-amis, var.aws_default_region)}"
#  aws_ami_user            = "${var.aws_ami_user}"
#  aws_flavor              = "${lookup(var.instances, "chef-build-node")}"
#  aws_subnet_id           = "${module.ec2-network.subnet_id}"
#  aws_security_groups_ids = "${module.ec2-network.chef-build-node_security_group_id}"
#  instance_count          = "${lookup(var.instance_counts, "chef-build-node")}"
#  aws_key_name            = "${var.aws_key_pair_name}"
#  aws_private_key_file    = "${path.cwd}/.keys/${var.aws_key_pair_name}.pem"
#  chef_server_url         = "${module.chef-server.chef-server-url}"
#  delivery_enterprise     = "terraform"
#  chef_organization       = "terraform"
#  chef_environment        = "_default"
#  # Maybe be this will create a dependency
#  # delivery_builder_keys = "${module.chef-delivery.delivery_builder_keys}"
#  delivery_enterprise     = "${module.chef-delivery.chef-delivery-enterprise}"
# }

# Setup Chef Supermarket
# Setup Chef Analytics
# Setup Chef Compliance
