# Infrastructure as Code (IaC)

## Terraform

### Базова конфігурація
```hcl
# Provider configuration
provider "aws" {
  region = "us-west-2"
}

# VPC resource
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "main"
  }
}

# Subnet resource
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
}

# EC2 instance
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
}
```

### Модулі
```hcl
# modules/vpc/main.tf
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
}
```

## Ansible

### Плейбуки
```yaml
# webserver.yml
---
- hosts: webservers
  become: yes
  tasks:
    - name: Install nginx
      apt:
        name: nginx
        state: present

    - name: Copy nginx config
      template:
        src: nginx.conf.j2
        dest: /etc/nginx/nginx.conf
      notify: restart nginx

    - name: Start nginx
      service:
        name: nginx
        state: started
        enabled: yes

  handlers:
    - name: restart nginx
      service:
        name: nginx
        state: restarted
```

### Ролі
```yaml
# roles/webserver/tasks/main.yml
---
- name: Install required packages
  apt:
    name: "{{ item }}"
    state: present
  loop:
    - nginx
    - php-fpm
    - mysql-client

# roles/webserver/handlers/main.yml
---
- name: restart nginx
  service:
    name: nginx
    state: restarted

# roles/webserver/templates/vhost.conf.j2
server {
    listen 80;
    server_name {{ domain_name }};
    root {{ web_root }};
}
```

## CloudFormation

### Базовий шаблон
```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Basic EC2 instance'

Parameters:
  InstanceType:
    Type: String
    Default: t2.micro
    AllowedValues:
      - t2.micro
      - t2.small

Resources:
  WebServerInstance:
    Type: AWS::EC2::Instance
    Properties:
      InstanceType: !Ref InstanceType
      ImageId: ami-0c55b159cbfafe1f0
      SecurityGroups:
        - !Ref WebServerSecurityGroup

  WebServerSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Enable HTTP access
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 80
          ToPort: 80
          CidrIp: 0.0.0.0/0
```

## Практичні завдання

### 1. Terraform
- Створити VPC з публічними та приватними підмережами
- Налаштувати Auto Scaling Group
- Створити S3 bucket з версіонуванням
- Налаштувати RDS інстанс

### 2. Ansible
- Автоматизувати налаштування веб-серверів
- Створити роль для деплою додатків
- Налаштувати моніторинг
- Автоматизувати бекапи

### 3. CloudFormation
- Створити мережеву інфраструктуру
- Налаштувати ECS кластер
- Створити піпелайн CI/CD
- Налаштувати моніторинг