variable "ami_filter_name" {
  default = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
}

variable "ami_filter_owner" {
  default = ["099720109477"] # Amazon
}

variable "ami_filter_virt_type" {
    default = ["hvm"]
}