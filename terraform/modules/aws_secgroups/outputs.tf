output "aws_sec_group_tcp_ports_id" {
  value = aws_security_group.network[*].id
}

output "aws_sec_group_tcp_ports_name" {
  value = aws_security_group.network[*].name
}