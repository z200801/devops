resource "aws_instance" "instance" {
  count           = var.instance_count
  ami             = var.instance_ami
  instance_type   = var.instance_type
  key_name        = element(var.instance_key_name[*], count.index)
  security_groups = var.security_groups
  vpc_security_group_ids = var.vpc_security_group_ids[*]
  subnet_id       = element(var.instance_subnets_cidr[*], count.index) #1
  user_data       = var.instance_user_data

  tags = {
    Name = "${var.instance_name}-${count.index}"
  }
}
