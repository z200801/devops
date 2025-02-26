#
# export TF_VAR_hcloud_token="Hetzner Api token"
#
variable "hcloud_token" {
  type        = string
  description = "Hetzner API Token"
  sensitive   = true
}

#
# export TF_VAR_user_passwoyrd="user_password_for_console"
#
variable "user_password" {
  type        = string
  description = "Password for the user account (ascces for console)"
  sensitive   = true
}

variable "node_config" {
  type        = map(any)
  description = "Parameters for server configurations"
  default = {
    location      = "eu-central"
    location_type = "nbg1"
    datacenter    = "nbg1-dc3"
    instances     = 1
    server_type   = "cax11"
    os_type       = "debian-12"
    environment   = "dev"
  }
}

variable "ip_range_private_1" {
  type    = string
  default = "10.10.1.0/24"
}

variable "tcp_in_ports" {
  type    = list(any)
  default = ["22", "80", "443"]
}

variable "udp_in_ports" {
  type    = list(any)
  default = ["51820"]
}

variable "ssh_key" {
  description = "SSH key setings"
  type        = map(any)
  default = {
    ssh_key_count = 1
    ssh_algorithm = "RSA"
    ssh_rsa_bit   = 4096
    ssh_key_name  = ".id-ssh-hetzner-node"
    ssh_key_dir   = "~/.ssh"
  }
}

locals {
  user_data = replace(
    var.user_data_template,
    "# Password will be inserted here",
    "- echo \"user:${var.user_password}\"|chpasswd"
  )
}

variable "user_data_template" {
  type    = string
  default = <<-EOT
#cloud-config
package_update: true
package_upgrade: true

packages:
  - curl
  - wget
  - vim
  - htop
  - tmux
  - git
  - apt-transport-https
  - ca-certificates
  - gnupg
  - lsb-release
  - ufw
  - btop
  - lazydocker
  - lazygit

timezone: Europe/Kiev
users:
  - name: user
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']

runcmd:
  - hostnamectl set-hostname node-$(hostname)
  - ufw allow 22/tcp
  - ufw allow 80/tcp
  - ufw allow 443/tcp
  - ufw allow 51820/udp
  - ufw --force enable
  # Password will be inserted here
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  - add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  - apt-get update
  - apt-get install -y docker-ce docker-ce-cli containerd.io
  - usermod -aG docker user
  - sed -ie '/^[#]PasswordAuthentication/s/^.*$/PasswordAuthentication no/' /etc/ssh/sshd_config
  - sed -ie '/^#MaxAuthTries/s/^.*$/MaxAuthTries 3/' /etc/ssh/sshd_config
  - sed -ie '/^[#]X11Forwarding/s/^.*$/X11Forwarding no/' /etc/ssh/sshd_config
  - service sshd restart
  - echo "$(date) - Cloud-init initialization complete" >> /var/log/cloud-init-complete.log

write_files:
  - path: /etc/systemd/system/docker-cleanup.service
    content: |
      [Unit]
      Description=Docker System Cleanup
      After=docker.service
      
      [Service]
      Type=oneshot
      ExecStart=/usr/bin/docker system prune -af
      
      [Install]
      WantedBy=multi-user.target
  EOT
}

