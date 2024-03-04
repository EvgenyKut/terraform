terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.108.1"
    }
  }
  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    bucket                      = "tf-intro-bucket"
    region                      = "ru-central1"
    key                         = "issue1/lemp.tfstate"
    access_key                  = "YCAJEcnU1jFdEfOYTjXoxNJ8t"
    secret_key                  = "YCMgTJ8tH_t1BurI-qBgT3kkEfdKhoC6QKjhErxv"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}

provider "yandex" {
  cloud_id                 = "b1g39gijtn2pjqn8i9ks"
  folder_id                = "b1g7ufob7k53rkebast4"
  service_account_key_file = "./authorized_key.json"
}

resource "yandex_vpc_network" "network" {
  name = "network"
}

data "yandex_compute_image" "my_image" {
  family = "lemp"
}

resource "yandex_compute_instance" "vm-1" {
  name = "terraform1"
  zone = "ru-central1-a"
  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.my_image.id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet1.id
    nat       = true
  }

  metadata = {
    user-data = file("./cloud-config.yaml")
  }
}

data "yandex_compute_image" "my_image2" {
  family = "lamp"
}

resource "yandex_compute_instance" "vm-2" {
  name = "terraform-lamp"
  zone = "ru-central1-b"
  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.my_image2.id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet2.id
    nat       = true
  }

  metadata = {
    user-data = file("./cloud-config.yaml")
  }
}

resource "yandex_vpc_subnet" "subnet1" {
  name           = "subnet1"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

resource "yandex_vpc_subnet" "subnet2" {
  name           = "subnet2"
  zone           = "ru-central1-b"  # Поменял зону для второй подсети
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["192.168.20.0/24"]
}

resource "yandex_lb_target_group" "my-test-target-group" {
  name      = "my-test-target-group"
  region_id = "ru-central1"

  target {
    subnet_id = yandex_vpc_subnet.subnet1.id
    address   = yandex_compute_instance.vm-1.network_interface.0.ip_address
  }

  target {
    subnet_id = yandex_vpc_subnet.subnet2.id
    address   = yandex_compute_instance.vm-2.network_interface.0.ip_address
  }
}

resource "yandex_lb_network_load_balancer" "my-balancer" {
  name = "my-network-load-balancer"

  listener {
    name = "my-listener"
    port = 8080
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.my-test-target-group.id

    healthcheck {
      name = "http"
      http_options {
        port = 8080
        path = "/ping"
      }
    }
  }
}

output "internal_ip_address_vm_1" {
  value = yandex_compute_instance.vm-1.network_interface.0.ip_address
}

output "external_ip_address_vm_1" {
  value = yandex_compute_instance.vm-1.network_interface.0.nat_ip_address
}

output "internal_ip_address_vm_2" {
  value = yandex_compute_instance.vm-2.network_interface.0.ip_address
}

output "external_ip_address_vm_2" {
  value = yandex_compute_instance.vm-2.network_interface.0.nat_ip_address
}
