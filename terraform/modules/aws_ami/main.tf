data "aws_ami" "last" {
  most_recent = true

  filter {
    name   = "name"
    values = var.ami_filter_name
  }

  filter {
    name   = "virtualization-type"
    values = var.ami_filter_virt_type
  }

  owners = var.ami_filter_owner
}
