# VPC
variable "vpc_1" {
  type = map(any)
  default = {
    cidr = "10.10.0.0/16"
    name = "vpc_test"
  }
}


# Instance
variable "inst_1" {
  type = map(any)
  default = {
    name         = "test"
    type         = "t2.micro"
    key_name     = "user"
    root_vl_size = "10"
    root_vl_type = "gp2"
    ebs_vl_size  = "10"
    ebs_vl_type  = "gp3"
    ebs_vl_name  = "/dev/sdb"
  }
}

# Security Group
variable "sg_ext" {
  type = map(any)
  default = {
    name = "external-access"
  }
}

variable "allowed_ip_22" {
  type    = list(any)
  default = ["0.0.0.0/0"]
}

