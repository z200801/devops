variable "aws_region" {
  default     = ""
}

variable "instance_name" {
  default = "instance-test"
}

variable "instance_ami" {
  default = ""
}

variable "instance_type" {
  default = "t2.micro"
}

variable "instance_key_name" {
  default = ""
}

variable "instance_user_data1" {
  default = <<EOF
  #!/bin/bash
  echo "Put script here"
  EOF
}

variable "instance_user_data" {
  default = ""
}

variable "security_groups" {
  default = []
}

variable "vpc_security_group_ids" {
 default = []
}

variable "instance_subnet_cidr" {
  default = ""
}

variable "iam_instance_profile" {
 default = ""
}

variable "instance_tag_name" {
  default = ""
}
