[[_TOC_]]

# Terraform + AWS. 

# About
Samples for make EC2 (Ubuntu 22.04) instance with:
 - Public IP
 - Add exist `user` SSH key
 - Security group ports:
   - In 22 from allowed IP
   - In 80, 443 for all
   - Out for all
   - root volume size 10Gb
   - EBS 10Gb and attached to /dev/xvdb

# Install
Need install:
 - AWS cli with configured credentials
 - Terraform

# Usage:

## Format and validate
```shell
terraform fmt 
terraform validate && terraform plan
```

## Apply
```shell
terraform apply #-auto-approve
```

## Destroy
```shell
terraform destroy #-auto-approve
```

## Connect to EC2
Variable `ec2_ssh_key_file` consist path+filename to EC2 key
```shell
#!/bin/bash

ec2_ssh_key_file=""
ec2_ip=$(terraform output|grep -Po "instance_.*\=\x20+\"\K\S+(?=\")")

if [ ! -e "${ec2_ssh_key_file}" ]; then echo "Error. SSH key file not exist. Exit."; exit 1; fi
ssh -i "${ec2_ssh_key_file}" ubuntu@"${ec2_ip}"
```

# Tune
`var.tf`
 inst_1
 - `type`         - AWS EC2 instance type. t2.micro - is free tier
 - `key_name`     - Existing SSH user in AWS 
 - `root_vl_size` - root directory size
 - `root_vl_type` - gp2, gp3 ...
 - `ebs_vl_XXXXX` - EBS type, size, name

 allowed_ip_22
 - `default` - whitelist ip for connect to ssh (22) port. As list
 
