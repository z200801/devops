# Vagrant та Віртуалізація

## Встановлення та Налаштування

### Встановлення
```bash
# Linux
sudo apt install vagrant
sudo apt install virtualbox
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils

# Vagrant plugins
vagrant plugin install vagrant-libvirt
vagrant plugin install vagrant-vbguest
```

### Базова конфігурація
```ruby
# Vagrantfile
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "2048"
    vb.cpus = 2
  end
end
```

## VirtualBox Provider

### Базові команди
```bash
# Управління VM
vagrant up
vagrant halt
vagrant destroy
vagrant ssh

# Box management
vagrant box add ubuntu/focal64
vagrant box list
vagrant box remove ubuntu/focal64
```

### Мережі
```ruby
Vagrant.configure("2") do |config|
  # Private network
  config.vm.network "private_network", ip: "192.168.56.10"
  
  # Port forwarding
  config.vm.network "forwarded_port", guest: 80, host: 8080
  
  # Public network
  config.vm.network "public_network", bridge: "en0"
end
```

## Libvirt Provider

### Конфігурація
```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "generic/ubuntu2004"
  
  config.vm.provider :libvirt do |libvirt|
    libvirt.memory = 2048
    libvirt.cpus = 2
    libvirt.nested = true
  end
end
```

### Мережі
```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.management_network_name = "vagrant-libvirt"
    libvirt.management_network_address = "192.168.121.0/24"
  end
end
```

## Provisioning

### Shell
```ruby
Vagrant.configure("2") do |config|
  config.vm.provision "shell", inline: <<-SHELL
    apt-get update
    apt-get install -y nginx
    systemctl start nginx
  SHELL
end
```

### Ansible
```ruby
Vagrant.configure("2") do |config|
  config.vm.provision "ansible" do |ansible|
    ansible.playbook = "playbook.yml"
    ansible.become = true
  end
end
```

## Multi-Machine Environment

```ruby
Vagrant.configure("2") do |config|
  config.vm.define "web" do |web|
    web.vm.box = "ubuntu/focal64"
    web.vm.network "private_network", ip: "192.168.56.10"
  end

  config.vm.define "db" do |db|
    db.vm.box = "ubuntu/focal64"
    db.vm.network "private_network", ip: "192.168.56.11"
  end
end
```

## Практичні завдання

### 1. Базове налаштування
- Створити Vagrantfile
- Налаштувати мережу
- Встановити пакети
- Налаштувати SSH

### 2. Multi-machine
- Створити кластер
- Налаштувати взаємодію
- Автоматизувати розгортання
- Синхронізувати файли

### 3. Provisioning
- Shell скрипти
- Ansible playbooks
- Налаштування сервісів
- Моніторинг

### 4. Production
- Оптимізація ресурсів
- Безпека
- Backup та відновлення
- Документування