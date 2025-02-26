resource "hcloud_network" "hc_private" {
  name     = "hc_private"
  ip_range = var.ip_range_private_1
}

resource "hcloud_network_subnet" "hc_private_subnet" {
  network_id   = hcloud_network.hc_private.id
  type         = "cloud"
  network_zone = var.node_config.location
  ip_range     = var.ip_range_private_1
}


resource "hcloud_primary_ip" "primary_ip_v6_1" {
  name          = "primary_ip_v6_1"
  type          = "ipv6"
  auto_delete   = false
  datacenter    = var.node_config.datacenter
  assignee_type = "server"
}

resource "hcloud_server_network" "node_network" {
  for_each  = { for idx in range(var.node_config.instances) : idx => idx }
  server_id = hcloud_server.node[each.key].id
  subnet_id = hcloud_network_subnet.hc_private_subnet.id
}


