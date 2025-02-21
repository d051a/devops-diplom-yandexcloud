# 1. Создаем VPC (общая сеть)
resource "yandex_vpc_network" "lab-net" {
  name = "network-1"
}

# 2. Создаем подсети в разных зонах
locals {
  subnets = [
    { name = "subnet-1", cidr = "10.10.10.0/24", zone = "ru-central1-a" },
    { name = "subnet-2", cidr = "10.10.40.0/24", zone = "ru-central1-b" },
    { name = "subnet-3", cidr = "10.10.50.0/24", zone = "ru-central1-b" }
  ]
}

resource "yandex_vpc_subnet" "lab-subnets" {
  for_each       = { for idx, subnet in local.subnets : subnet.name => subnet }
  name           = each.value.name
  v4_cidr_blocks = [each.value.cidr]
  zone           = each.value.zone
  network_id     = yandex_vpc_network.lab-net.id
}

# 3. Создаем ВМ в разных подсетях
locals {
  instances = [
    { name = "k8s-master", zone = "ru-central1-a", subnet = "subnet-1", cores = 2, memory = 4 },
    { name = "k8s-worker-1", zone = "ru-central1-b", subnet = "subnet-2", cores = 2, memory = 6 },
    { name = "k8s-worker-2", zone = "ru-central1-b", subnet = "subnet-3", cores = 2, memory = 6 }
  ]
}

resource "yandex_compute_instance" "instances" {
  for_each    = { for idx, instance in local.instances : instance.name => instance }
  name        = each.value.name
  platform_id = "standard-v1"
  zone        = each.value.zone

  resources {
    cores  = each.value.cores
    memory = each.value.memory
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu-2004-lts.image_id
      type     = "network-hdd"
      size     = 15
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.lab-subnets[each.value.subnet].id
    nat       = true  # Публичный IP
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

data "yandex_compute_image" "ubuntu-2004-lts" {
  family = "ubuntu-2004-lts"
}

# 4. Генерация Ansible inventory
locals {
  ansible_inventory = <<EOT
[k8s-master]
%{for instance in yandex_compute_instance.instances ~}
%{if instance.name == "k8s-master"}
${instance.network_interface.0.nat_ip_address} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
%{endif}
%{endfor}

[k8s-workers]
%{for instance in yandex_compute_instance.instances ~}
%{if instance.name != "k8s-master"}
${instance.network_interface.0.nat_ip_address} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
%{endif}
%{endfor}
EOT
}

output "ansible_inventory" {
  value = local.ansible_inventory
}

resource "local_file" "ansible_inventory" {
  filename = "ansible_inventory.ini"
  content  = local.ansible_inventory
}

# 5. Генерация inventory для Kubespray
locals {
  kubespray_inventory = <<EOT
[kube_control_plane]
node1 ansible_host=${yandex_compute_instance.instances["k8s-master"].network_interface.0.nat_ip_address} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa etcd_member_name=etcd1

[etcd]
node1 ansible_host=${yandex_compute_instance.instances["k8s-master"].network_interface.0.nat_ip_address} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa

[kube_node]
%{for instance in yandex_compute_instance.instances ~}
%{if instance.name != "k8s-master"}
node-${instance.name} ansible_host=${instance.network_interface.0.nat_ip_address} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
%{endif}
%{endfor}

[k8s_cluster:children]
kube_control_plane
kube_node
etcd
EOT
}

resource "local_file" "kubespray_inventory" {
  filename = "inventory.ini"
  content  = local.kubespray_inventory
}