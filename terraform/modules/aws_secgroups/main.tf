resource "aws_security_group" "network" {
  count = length(var.sec_group_ports_tcp_open)
  name        = "${var.env}-${var.sec_group_ports_tcp_open[count.index]}"

  ingress {
    from_port   = element(var.sec_group_ports_tcp_open[*], count.index)
    to_port     = element(var.sec_group_ports_tcp_open[*], count.index)
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
