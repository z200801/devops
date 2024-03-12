resource "aws_instance" "inst_1" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.inst_1.type
  key_name                    = var.inst_1.key_name
  vpc_security_group_ids      = [aws_security_group.external_access.id]
  associate_public_ip_address = true

  tags = {
    Name = "${var.inst_1.name}_1"
  }

  root_block_device {
    volume_size = var.inst_1.root_vl_size
    volume_type = var.inst_1.root_vl_type
  }

  # If need add EBS uncoment block [ebs_block_device]
  # This block is [/dev/xvdb]
  # ebs_block_device {
  #   device_name = var.inst_1.ebs_vl_name
  #   volume_type = var.inst_1.ebs_vl_type
  #   volume_size = var.inst_1.ebs_vl_size
  # }
  user_data = <<-EOF
     #!/bin/bash
     apt updae && apt -y upgrade && apt install -y docker.io docker-compose
     EOF
}
