# -----------------[ Network ACL: default ]-----------------
resource "aws_default_network_acl" "default" {
  default_network_acl_id = aws_vpc.vpc_1.default_network_acl_id

  ingress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }


  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = { Name = "default" }
}

#-----------------[ Sequrity group: internal_access ]-----------------
# This bloc code [aws_security_group] and some [aws_security_group_rule] work
resource "aws_security_group" "external_access" {
  name = var.sg_ext.name
  tags = { Name = var.sg_ext.name }
}

resource "aws_security_group_rule" "allow_external_ssh" {
  security_group_id = aws_security_group.external_access.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.allowed_ip_22
}

resource "aws_security_group_rule" "allow_external_http" {
  security_group_id = aws_security_group.external_access.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_external_https" {
  security_group_id = aws_security_group.external_access.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_external_traffic_eggress" {
  security_group_id = aws_security_group.external_access.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# This block code [aws_security_group.external_access] work
#
# resource "aws_security_group" "external_access" {
#   name        = var.sg_ext_var.name
#   description = "Open SSH (22) port for in and allow all to out"
#   tags        = { Name = var.sg_ext_var.name }
#
#   ingress {
#     from_port = 22
#     to_port   = 22
#     protocol  = "tcp"
#     # cidr_blocks = ["0.0.0.0/0"]
#     cidr_blocks = var.allowed_ip_22
#   }
#
#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#
#   ingress {
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }
