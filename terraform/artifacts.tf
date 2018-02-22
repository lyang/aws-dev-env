resource "local_file" "ec2-user-pem" {
  content  = "${tls_private_key.ec2-user.private_key_pem}"
  filename = "${path.root}/../generated/ssh-keys/ec2-user.pem"

  provisioner "local-exec" {
    command = "chmod 0400 ${self.filename}"
  }
}

resource "local_file" "admin-pem" {
  content  = "${tls_private_key.admin.private_key_pem}"
  filename = "${path.root}/../generated/ssh-keys/admin.pem"

  provisioner "local-exec" {
    command = "chmod 0400 ${self.filename}"
  }
}

resource "local_file" "admin-pub" {
  content  = "${tls_private_key.admin.public_key_openssh}"
  filename = "${path.root}/../generated/ssh-keys/admin.pub"
}

resource "local_file" "inventory" {
  content  = "${data.template_file.inventory.rendered}"
  filename = "${path.root}/../generated/inventory/inventory.yml"
}

resource "local_file" "group-vars-pristine" {
  content  = "${data.template_file.group-vars-pristine.rendered}"
  filename = "${path.root}/../generated/inventory/group_vars/pristine.yml"
}

resource "local_file" "group-vars-managed" {
  content  = "${data.template_file.group-vars-managed.rendered}"
  filename = "${path.root}/../generated/inventory/group_vars/managed.yml"
}
