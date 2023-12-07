resource "aws_instance" "instance" {
  ami             = var.instance_ami
  instance_type   = var.instance_type
  key_name        = var.instance_key_name
  security_groups = var.security_groups
  vpc_security_group_ids = var.vpc_security_group_ids[*]
  subnet_id       = var.instance_subnet_cidr
  iam_instance_profile = var.iam_instance_profile
  user_data       = var.instance_user_data

  tags = {
    Name = var.instance_tag_name
  }
}
