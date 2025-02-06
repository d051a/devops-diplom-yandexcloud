# 1. Создаем VPC (общая сеть)
resource "yandex_vpc_network" "lab-net" {
  name = "network-1"
}

# 2. Создаем три подсети (в разных зонах)
resource "yandex_vpc_subnet" "lab-subnet-a" {
  name           = "subnet-1"
  v4_cidr_blocks = ["10.10.10.0/24"]
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.lab-net.id
}

resource "yandex_vpc_subnet" "lab-subnet-b" {
  name           = "subnet-2"
  v4_cidr_blocks = ["10.10.40.0/24"]
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.lab-net.id
}

resource "yandex_vpc_subnet" "lab-subnet-b2" {
  name           = "subnet-3"
  v4_cidr_blocks = ["10.10.50.0/24"]
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.lab-net.id
}

# 3. Создаем три ВМ (по одной в каждой подсети)
resource "yandex_compute_instance" "k8s-master" {
  name        = "k8s-master"
  platform_id = "standard-v1"
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu-2004-lts.image_id
      type     = "network-hdd"
      size     = 15
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.lab-subnet-a.id
    nat       = true  # Публичный IP
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_compute_instance" "k8s-worker-1" {
  name        = "k8s-worker-1"
  platform_id = "standard-v1"
  zone        = "ru-central1-b"

  resources {
    cores  = 2
    memory = 8
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu-2004-lts.image_id
      type     = "network-hdd"
      size     = 15
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.lab-subnet-b.id
    nat       = true  # Публичный IP
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_compute_instance" "k8s-worker-2" {
  name        = "k8s-worker-2"
  platform_id = "standard-v1"
  zone        = "ru-central1-b"

  resources {
    cores  = 2
    memory = 8
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu-2004-lts.image_id
      type     = "network-hdd"
      size     = 15
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.lab-subnet-b2.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

data "yandex_compute_image" "ubuntu-2004-lts" {
  family = "ubuntu-2004-lts"
}


# 4. Выводим Ansible inventory в консоль
output "ansible_inventory" {
  value = <<EOT
[k8s-master]
${yandex_compute_instance.k8s-master.network_interface.0.nat_ip_address} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa

[k8s-workers]
${yandex_compute_instance.k8s-worker-1.network_interface.0.nat_ip_address} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
${yandex_compute_instance.k8s-worker-2.network_interface.0.nat_ip_address} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
EOT
}

# 5. Записываем inventory в файл для Ansible
resource "local_file" "ansible_inventory" {
  filename = "ansible_inventory.ini"
  content  = <<EOT
[k8s-master]
${yandex_compute_instance.k8s-master.network_interface.0.nat_ip_address} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa

[k8s-workers]
${yandex_compute_instance.k8s-worker-1.network_interface.0.nat_ip_address} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
${yandex_compute_instance.k8s-worker-2.network_interface.0.nat_ip_address} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
EOT
}

# 6. Записываем inventory в файл для kubespray
resource "local_file" "kubespray_inventory" {
  filename = "inventory.ini"
  content  = <<EOT
[kube_control_plane]
node1 ansible_host=${yandex_compute_instance.k8s-master.network_interface.0.nat_ip_address} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa etcd_member_name=etcd1

[etcd]
node1 ansible_host=${yandex_compute_instance.k8s-master.network_interface.0.nat_ip_address} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa

[kube_node]
node2 ansible_host=${yandex_compute_instance.k8s-worker-1.network_interface.0.nat_ip_address} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
node3 ansible_host=${yandex_compute_instance.k8s-worker-2.network_interface.0.nat_ip_address} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa

[k8s_cluster:children]
kube_control_plane
kube_node
etcd
EOT
}