# Setup chef-server
resource "aws_instance" "chef-server" {
  ami = "${var.ami}"
  count = "${var.count}"
  instance_type = "${var.instance_type}"
  subnet_id = "${var.subnet_id}"
  vpc_security_group_ids = ["${var.security_groups_ids}"]
  key_name = "${var.key_name}"
  tags {
    Name = "${format("chef-server-%02d", count.index + 1)}"
  }
  root_block_device = {
    delete_on_termination = true
  }
  connection {
    user = "${var.user}"
    private_key = "${var.private_key_path}"
  }

  # Copies all cookbooks that we need to trigger a chef-zero
  provisioner "file" {
    source = "cookbooks"
    destination = "/tmp"
  }

  # Render a DNA json file
  provisioner "remote-exec" {
    inline = <<EOF
    cat <<FILE > /tmp/dna.json
{
  "chef-server-12": {
    "api_fqdn": "${self.public_ip}",
    "delivery": {
      "organization": "${var.organization}"
    }
  }
}
FILE
EOF
  }

  # Install ChefDK and converge chef-server-12 cookbook
  provisioner "remote-exec" {
    inline = [
      "sudo service iptables stop",
      "sudo chkconfig iptables off",
      "curl -LO https://www.chef.io/chef/install.sh && sudo bash ./install.sh -P chefdk -n && rm install.sh",
      "cd /tmp; sudo chef exec chef-client -z -o chef-server-12 -j /tmp/dna.json"
    ]
  }

  # TODO: How terraform can download files? If it doesn't then we may have to triangle the files
  #       that is (perhaps) upload the files somewhere or create a data bag and store them there.
  #
  # Workaround: Use scp to download the files we need to push them to the rest of the cluster
  provisioner "local-exec" {
    command  = "scp -oStrictHostKeyChecking=no -i ${var.private_key_path} ${var.user}@${self.public_ip}:/tmp/delivery.pem .chef/delivery.pem"
  }
  # Workaround: Use scp to download the validator-pem
  provisioner "local-exec" {
    command  = "scp -oStrictHostKeyChecking=no -i ${var.private_key_path} ${var.user}@${self.public_ip}:/tmp/validator.pem .chef/${var.organization}-validator.pem"
  }
}

# Template to render knife.rb
resource "template_file" "knife_rb" {
  template = "${file("${path.module}/templates/knife_rb.tpl")}"
  vars {
    chef-server-fqdn = "${aws_instance.chef-server.public_ip}"
    organization = "${var.organization}"
  }
  provisioner "local-exec" {
    command = "echo '${template_file.knife_rb.rendered}' > .chef/knife.rb"
  }
  # Fetch Chef Server Certificate
  provisioner "local-exec" {
    command = "knife ssl fetch"
  }
  # Upload cookbooks to the Chef Server
  provisioner "local-exec" {
    command = "knife cookbook upload --all --cookbook-path cookbooks"
  }
}
