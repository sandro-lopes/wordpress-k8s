#!/bin/bash
# Script para implantar WordPress com MySQL no Kubernetes
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

# Verificar se o K3s está instalado
print_info "Verificando se o K3s está instalado..."
if ! command -v kubectl >/dev/null 2>&1; then
  print_error "K3s não está instalado. Por favor, instale-o primeiro."
fi

# Verificar o status do K3s
print_info "Verificando o status do K3s..."
if ! sudo systemctl is-active --quiet k3s; then
  print_error "K3s não está ativo. Por favor, inicie o serviço com 'sudo systemctl start k3s'"
fi
print_success "K3s está ativo e pronto"

# Configurar kubectl (por precaução)
print_info "Configurando kubectl..."
mkdir -p ~/.kube
if [ ! -f ~/.kube/config ]; then
  sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
  sudo chown $(id -u):$(id -g) ~/.kube/config
fi
export KUBECONFIG=~/.kube/config
print_success "kubectl configurado"

# Determinar o diretório base do projeto
# Se o script estiver em um diretório 'scripts', volte um nível
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
if [[ "$SCRIPT_DIR" == *"/scripts" ]]; then
    BASE_DIR="$(dirname "$SCRIPT_DIR")"
else
    BASE_DIR="$SCRIPT_DIR"
fi

# Implantando MySQL
print_info "Implantando MySQL..."
kubectl apply -f "$BASE_DIR/kubernetes/mysql-pvc.yaml"
kubectl apply -f "$BASE_DIR/kubernetes/mysql-secret.yaml"
kubectl apply -f "$BASE_DIR/kubernetes/mysql-deployment.yaml"
kubectl apply -f "$BASE_DIR/kubernetes/mysql-service.yaml"
print_success "MySQL implantado"

# Aguardar o MySQL estar pronto
print_info "Aguardando o MySQL estar pronto..."
kubectl wait --for=condition=ready pod -l app=wordpress,tier=mysql --timeout=300s || print_error "Timeout esperando o MySQL ficar pronto"
print_success "MySQL está pronto"

# Implantando WordPress
print_info "Implantando WordPress..."
kubectl apply -f "$BASE_DIR/kubernetes/wordpress-pvc.yaml"
kubectl apply -f "$BASE_DIR/kubernetes/wordpress-deployment.yaml"
kubectl apply -f "$BASE_DIR/kubernetes/wordpress-service.yaml"
kubectl apply -f "$BASE_DIR/kubernetes/wordpress-ingress.yaml"
print_success "WordPress implantado"

# Aguardar o WordPress estar pronto
print_info "Aguardando o WordPress estar pronto..."
kubectl wait --for=condition=ready pod -l app=wordpress,tier=frontend --timeout=300s || print_error "Timeout esperando o WordPress ficar pronto"
print_success "WordPress está pronto"

# Configurar o acesso ao WordPress
print_info "Configurando acesso ao WordPress..."
INGRESS_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
if [ -z "$INGRESS_IP" ]; then
  INGRESS_IP=$(hostname -I | awk '{print $1}')
fi

echo "Você precisa adicionar a seguinte entrada ao seu arquivo /etc/hosts:"
echo "$INGRESS_IP wordpress.local"
read -p "Deseja adicionar automaticamente ao /etc/hosts? (s/n): " add_hosts

if [[ "$add_hosts" == "s" || "$add_hosts" == "S" ]]; then
  echo "$INGRESS_IP wordpress.local" | sudo tee -a /etc/hosts
  print_success "Entrada adicionada ao /etc/hosts"
fi

# Exibir informações sobre como acessar via Killercoda
print_info "Se você está usando o Killercoda:"
echo "1. Clique no ícone 'hambuguer' no topo à direita do terminal"
echo "2. Selecione 'Traffic / Ports'"
echo "3. Digite a porta 80 e clique em 'Access'"
echo ""
print_info "Se encontrar erro '404 page not found', tente o seguinte:"
echo "Execute: kubectl port-forward svc/wordpress 8080:80 &"
echo "Em seguida, acesse novamente pelo ícone 'hambuguer', selecionando 'Traffic / Ports' com a porta 8080"
echo "Ou execute o comando: kubectl port-forward svc/wordpress 8080:80 e acesse http://localhost:8080"

print_info "Para acessar de sua máquina local (se disponível):"
echo "1. Use a interface web do Killercoda conforme acima, ou"
echo "2. Configure sua máquina local:"
echo "   - Adicione '$INGRESS_IP wordpress.local' ao arquivo /etc/hosts local"
echo "   - Se disponível, crie um túnel SSH: ssh -L 80:$INGRESS_IP:80 usuario@endereco-do-killercoda"
echo "   - Acesse http://wordpress.local no seu navegador local"
echo "Nota: A acessibilidade externa depende das configurações do ambiente Killercoda"

# Exibir informações finais
print_info "Implantação concluída!"
echo "======================================================================="
echo "WordPress está disponível em: http://wordpress.local"
echo "Para verificar o status dos pods: kubectl get pods"
echo "Para acessar os logs do WordPress: kubectl logs -l app=wordpress,tier=frontend"
echo "Para acessar os logs do MySQL: kubectl logs -l app=wordpress,tier=mysql"
echo "======================================================================="
print_success "Aproveite seu novo ambiente WordPress!" 