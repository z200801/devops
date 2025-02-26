resource "hcloud_firewall" "node_firewall_icmp" {
  name = "node-firewall-icmp"
  rule {
    direction = "in"
    protocol  = "icmp"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
}

resource "hcloud_firewall" "node_firewall_tcp" {
  name = "node-firewall-tcp"
  dynamic "rule" {
    for_each = toset(var.tcp_in_ports)
    content {
      port       = rule.value
      direction  = "in"
      protocol   = "tcp"
      source_ips = ["0.0.0.0/0", "::/0"]
    }
  }
}

resource "hcloud_firewall" "node_firewall_udp" {
  name = "node-firewall-udp"
  dynamic "rule" {
    for_each = toset(var.udp_in_ports)
    content {
      port       = rule.value
      direction  = "in"
      protocol   = "udp"
      source_ips = ["0.0.0.0/0", "::/0"]
    }
  }
}
