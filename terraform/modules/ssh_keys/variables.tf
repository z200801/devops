variable "ssh_key_count" {
  default = 0
}

variable "ssh_algorithm" {
    default = "RSA"
}

variable "ssh_rsa_bit" {
    default = 4096
}

variable "ssh_key_name" {
    default = "ssh_key_tmp"
}

variable "ssh_key_dir" {
    default = "./"
}
