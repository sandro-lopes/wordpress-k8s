terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20.0"
    }
  }
  required_version = ">= 1.0.0"
}

provider "kubernetes" {
  config_path = var.kube_config_path
}

# MySQL Resources
resource "kubernetes_persistent_volume_claim" "mysql_pvc" {
  metadata {
    name = "mysql-pvc"
    labels = {
      app = "wordpress"
    }
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
}

resource "kubernetes_secret" "mysql_secret" {
  metadata {
    name = "mysql-secret"
    labels = {
      app = "wordpress"
    }
  }
  data = {
    "mysql-root-password" = "d29yZHByZXNzMTIz"  # wordpress123 em base64
    "mysql-password"      = "d29yZHByZXNzMTIz"  # wordpress123 em base64
    "mysql-database"      = "d29yZHByZXNz"      # wordpress em base64
  }
  type = "Opaque"
}

resource "kubernetes_deployment" "mysql" {
  metadata {
    name = "mysql"
    labels = {
      app = "wordpress"
    }
  }
  spec {
    selector {
      match_labels = {
        app  = "wordpress"
        tier = "mysql"
      }
    }
    strategy {
      type = "Recreate"
    }
    template {
      metadata {
        labels = {
          app  = "wordpress"
          tier = "mysql"
        }
      }
      spec {
        container {
          image = "mysql:5.7"
          name  = "mysql"
          env {
            name = "MYSQL_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql_secret.metadata[0].name
                key  = "mysql-root-password"
              }
            }
          }
          env {
            name = "MYSQL_DATABASE"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql_secret.metadata[0].name
                key  = "mysql-database"
              }
            }
          }
          env {
            name = "MYSQL_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql_secret.metadata[0].name
                key  = "mysql-password"
              }
            }
          }
          port {
            container_port = 3306
            name           = "mysql"
          }
          volume_mount {
            name       = "mysql-persistent-storage"
            mount_path = "/var/lib/mysql"
          }
          resources {
            limits = {
              memory = "512Mi"
              cpu    = "500m"
            }
            requests = {
              memory = "256Mi"
              cpu    = "250m"
            }
          }
        }
        volume {
          name = "mysql-persistent-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.mysql_pvc.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "mysql" {
  metadata {
    name = "mysql"
    labels = {
      app = "wordpress"
    }
  }
  spec {
    selector = {
      app  = "wordpress"
      tier = "mysql"
    }
    port {
      port = 3306
    }
    cluster_ip = "None"
  }
}

# WordPress Resources
resource "kubernetes_persistent_volume_claim" "wordpress_pvc" {
  metadata {
    name = "wordpress-pvc"
    labels = {
      app = "wordpress"
    }
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}

resource "kubernetes_deployment" "wordpress" {
  metadata {
    name = "wordpress"
    labels = {
      app = "wordpress"
    }
  }
  spec {
    selector {
      match_labels = {
        app  = "wordpress"
        tier = "frontend"
      }
    }
    strategy {
      type = "Recreate"
    }
    template {
      metadata {
        labels = {
          app  = "wordpress"
          tier = "frontend"
        }
      }
      spec {
        container {
          image = "wordpress:latest"
          name  = "wordpress"
          env {
            name  = "WORDPRESS_DB_HOST"
            value = "mysql"
          }
          env {
            name = "WORDPRESS_DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql_secret.metadata[0].name
                key  = "mysql-password"
              }
            }
          }
          env {
            name  = "WORDPRESS_DB_USER"
            value = "root"
          }
          env {
            name = "WORDPRESS_DB_NAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql_secret.metadata[0].name
                key  = "mysql-database"
              }
            }
          }
          port {
            container_port = 80
            name           = "wordpress"
          }
          volume_mount {
            name       = "wordpress-persistent-storage"
            mount_path = "/var/www/html"
          }
          resources {
            limits = {
              memory = "512Mi"
              cpu    = "500m"
            }
            requests = {
              memory = "256Mi"
              cpu    = "250m"
            }
          }
        }
        volume {
          name = "wordpress-persistent-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.wordpress_pvc.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "wordpress" {
  metadata {
    name = "wordpress"
    labels = {
      app = "wordpress"
    }
  }
  spec {
    selector = {
      app  = "wordpress"
      tier = "frontend"
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "wordpress_ingress" {
  metadata {
    name = "wordpress-ingress"
    annotations = {
      "nginx.ingress.kubernetes.io/rewrite-target" = "/"
    }
  }
  spec {
    rule {
      host = "wordpress.local"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.wordpress.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
} 