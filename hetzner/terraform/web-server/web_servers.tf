resource "hcloud_server" "node" {
  for_each = { for idx in range(var.node_config.instances) : idx => "node-${idx}" }

  name         = each.value
  image        = var.node_config.os_type
  server_type  = var.node_config.server_type
  location     = var.node_config.location_type
  ssh_keys     = [hcloud_ssh_key.ssh[each.key].id]
  firewall_ids = [hcloud_firewall.node_firewall_tcp.id, hcloud_firewall.node_firewall_icmp.id, hcloud_firewall.node_firewall_udp.id]

  public_net {
    ipv4_enabled = false
    ipv6         = hcloud_primary_ip.primary_ip_v6_1.id
  }

  labels = {
    type = "node-${each.key}"
  }

  lifecycle {
    ignore_changes = [public_net, user_data]
  }

  user_data = local.user_data
}
