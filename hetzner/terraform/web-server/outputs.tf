output "ssh_public_key_pem" {
  value = tls_private_key.ssh[*].public_key_pem
}

output "ssh_public_key_name" {
  value = hcloud_ssh_key.ssh[*].name
}


output "node_servers_status" {
  value = {
    for server in hcloud_server.node :
    server.name => server.status
  }
}

output "node_servers_ips_v4" {
  value = {
    for server in hcloud_server.node :
    server.name => server.ipv4_address
  }
}

output "node_servers_ips_v6" {
  value = {
    for server in hcloud_server.node :
    server.name => server.ipv6_address
  }
}
