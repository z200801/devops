resource "tls_private_key" "ssh" {
  count     = var.ssh_key.ssh_key_count
  algorithm = var.ssh_key.ssh_algorithm
  rsa_bits  = var.ssh_key.ssh_rsa_bit
}

resource "hcloud_ssh_key" "ssh" {
  count      = var.ssh_key.ssh_key_count
  name       = "${var.ssh_key.ssh_key_name}-${count.index}"
  public_key = tls_private_key.ssh[count.index].public_key_openssh
  labels = {
    "environment" = var.node_config.environment
    "name"        = "ssh_key-${count.index}"
    "type"        = var.ssh_key.ssh_algorithm
    "index"       = count.index
  }
}

resource "local_sensitive_file" "ssh_pem_file" {
  count           = var.ssh_key.ssh_key_count
  filename        = pathexpand("${var.ssh_key.ssh_key_dir}/${hcloud_ssh_key.ssh[count.index].name}.pem")
  file_permission = "600"
  content         = tls_private_key.ssh[count.index].private_key_pem
}


