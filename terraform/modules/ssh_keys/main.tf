# Module create ssh key

resource "tls_private_key" "ssh" {
  count = var.ssh_key_count
  algorithm = var.ssh_algorithm
  rsa_bits  = var.ssh_rsa_bit
}

resource "aws_key_pair" "ssh" {
  count = var.ssh_key_count
  key_name   = "${var.ssh_key_name}-${count.index}"
  public_key = tls_private_key.ssh[count.index].public_key_openssh
}

resource "local_sensitive_file" "ssh_pem_file" {
  count = var.ssh_key_count
  filename        = pathexpand("${var.ssh_key_dir}/${aws_key_pair.ssh[count.index].key_name}.pem")
  file_permission = "600"
  content = tls_private_key.ssh[count.index].private_key_pem
}