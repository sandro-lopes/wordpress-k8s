#!/bin/bash
# Script para remover todos os recursos do WordPress e MySQL no Kubernetes
# Autor: Equipe DevOps

# Definindo cores para melhor visualização
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Função para imprimir mensagem de sucesso
function print_success() {
  echo -e "${GREEN}[SUCESSO]${NC} $1"
}

# Função para imprimir mensagem de erro
function print_error() {
  echo -e "${RED}[ERRO]${NC} $1"
  exit 1
}

# Função para imprimir mensagem de informação
function print_info() {
  echo -e "${YELLOW}[INFO]${NC} $1"
}

# Verificar se o kubectl está disponível
print_info "Verificando se o K3s está instalado..."
if ! command -v kubectl >/dev/null 2>&1; then
  print_error "K3s não está instalado ou kubectl não está disponível."
fi

# Determinar o diretório base do projeto
# Se o script estiver em um diretório 'scripts', volte um nível
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
if [[ "$SCRIPT_DIR" == *"/scripts" ]]; then
    BASE_DIR="$(dirname "$SCRIPT_DIR")"
else
    BASE_DIR="$SCRIPT_DIR"
fi

# Confirmação para continuar
echo "ATENÇÃO: Este script removerá todos os recursos do WordPress e MySQL do seu cluster Kubernetes."
echo "Isso inclui TODOS os dados armazenados no WordPress e no banco de dados MySQL."
echo "Esta ação NÃO PODE ser desfeita!"
read -p "Tem certeza que deseja continuar? (s/n): " confirm

if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
  print_info "Operação cancelada pelo usuário."
  exit 0
fi

# Remover recursos do WordPress
print_info "Removendo recursos do WordPress..."
kubectl delete -f "$BASE_DIR/kubernetes/wordpress-ingress.yaml" || true
kubectl delete -f "$BASE_DIR/kubernetes/wordpress-service.yaml" || true
kubectl delete -f "$BASE_DIR/kubernetes/wordpress-deployment.yaml" || true
print_success "Recursos do WordPress removidos"

# Remover recursos do MySQL
print_info "Removendo recursos do MySQL..."
kubectl delete -f "$BASE_DIR/kubernetes/mysql-service.yaml" || true
kubectl delete -f "$BASE_DIR/kubernetes/mysql-deployment.yaml" || true
kubectl delete -f "$BASE_DIR/kubernetes/mysql-secret.yaml" || true
print_success "Recursos do MySQL removidos"

# Perguntar se deseja remover os volumes persistentes
read -p "Deseja remover também os volumes persistentes (TODOS OS DADOS SERÃO PERDIDOS)? (s/n): " remove_pvc

if [[ "$remove_pvc" == "s" || "$remove_pvc" == "S" ]]; then
  print_info "Removendo volumes persistentes..."
  kubectl delete -f "$BASE_DIR/kubernetes/wordpress-pvc.yaml" || true
  kubectl delete -f "$BASE_DIR/kubernetes/mysql-pvc.yaml" || true
  print_success "Volumes persistentes removidos"
else
  print_info "Volumes persistentes mantidos"
  echo "Os volumes persistentes foram mantidos. Se você reimplantar a aplicação, os dados anteriores ainda estarão disponíveis."
fi

# Remover entrada do /etc/hosts
print_info "Verificando entrada no arquivo /etc/hosts..."
if grep -q "wordpress.local" /etc/hosts; then
  read -p "Deseja remover a entrada 'wordpress.local' do arquivo /etc/hosts? (s/n): " remove_hosts
  
  if [[ "$remove_hosts" == "s" || "$remove_hosts" == "S" ]]; then
    sudo sed -i '/wordpress.local/d' /etc/hosts
    print_success "Entrada removida do arquivo /etc/hosts"
  else
    print_info "Entrada mantida no arquivo /etc/hosts"
  fi
fi

# Perguntar se deseja desinstalar o K3s
read -p "Deseja desinstalar completamente o K3s? (s/n): " uninstall_k3s

if [[ "$uninstall_k3s" == "s" || "$uninstall_k3s" == "S" ]]; then
  print_info "Desinstalando K3s..."
  if [ -f /usr/local/bin/k3s-uninstall.sh ]; then
    sudo /usr/local/bin/k3s-uninstall.sh
    print_success "K3s foi desinstalado"
  else
    print_error "Script de desinstalação do K3s não encontrado"
  fi
fi

# Exibir informações finais
print_info "Limpeza concluída!"
echo "======================================================================="
echo "Todos os recursos do WordPress e MySQL foram removidos do cluster Kubernetes."
if [[ "$remove_pvc" != "s" && "$remove_pvc" != "S" ]]; then
  echo "Os volumes persistentes foram mantidos e podem ser reutilizados em uma nova implantação."
fi
echo "======================================================================="
print_success "Operação concluída com sucesso!" 