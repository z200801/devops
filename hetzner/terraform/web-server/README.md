# Server in Hetzner with Terraform

 Create servers in Hetzner Cloude with

- Debian 12
- private network 10.10.1.0/24
- open ports:
  - tcp: 22, 80, 443
  - udp: 51820 (WireGuard)
- post install app in `user_data` section

 Change server setings in variable file `variables.tf` section `node_config`
  
## Usage

Export Hetzner token and user password

```sh
export TF_VAR_hcloud_token="your_hetzner_api_token_here"
export TF_VAR_user_password="user_password_for_console"
```

Validate

```sh
terraform fmt && \
terraform validate && \
terraform plan
```

Apply

```sh
terraform apply
```
