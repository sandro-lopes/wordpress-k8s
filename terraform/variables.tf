variable "kube_config_path" {
  description = "Caminho para o arquivo de configuração do Kubernetes"
  type        = string
  default     = "~/.kube/config"
} 