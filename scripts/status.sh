#!/bin/bash
# Script para verificar o status da aplicação WordPress e MySQL no Kubernetes

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

function print_section() {
  echo -e "\n${BLUE}=== $1 ===${NC}"
}

function print_info() {
  echo -e "${YELLOW}[INFO]${NC} $1"
}

if ! command -v kubectl >/dev/null 2>&1; then
  echo -e "${RED}[ERRO]${NC} K3s não está instalado ou kubectl não está disponível."
  exit 1
fi

echo -e "${GREEN}======================================================${NC}"
echo -e "${GREEN}===  VERIFICAÇÃO DE STATUS WORDPRESS + MYSQL K8S  ===${NC}"
echo -e "${GREEN}======================================================${NC}"

print_section "Status do K3s"
sudo systemctl status k3s --no-pager | head -n 3

print_section "Status dos Pods"
kubectl get pods -o wide

print_section "Status dos Serviços"
kubectl get services

print_section "Status do Ingress"
kubectl get ingress

print_section "Status dos Volumes Persistentes"
kubectl get pvc

print_section "Status dos Secrets"
kubectl get secrets | grep mysql

print_section "Status dos Deployments"
kubectl get deployments

print_section "Logs do WordPress (últimas 5 linhas)"
kubectl logs -l app=wordpress,tier=frontend --tail=5 || echo "Nenhum pod WordPress encontrado"

print_section "Logs do MySQL (últimas 5 linhas)"
kubectl logs -l app=wordpress,tier=mysql --tail=5 || echo "Nenhum pod MySQL encontrado"

print_section "Verificando Acessibilidade do WordPress"
if grep -q "wordpress.local" /etc/hosts; then
  print_info "Entrada wordpress.local encontrada no arquivo /etc/hosts"
  
  if curl -s -o /dev/null -w "%{http_code}" http://wordpress.local > /dev/null 2>&1; then
    echo -e "${GREEN}[OK]${NC} WordPress está acessível em http://wordpress.local"
  else
    echo -e "${RED}[FALHA]${NC} Não foi possível acessar o WordPress em http://wordpress.local"
    
    print_info "Tentando acessar via port-forward..."
    kubectl port-forward svc/wordpress 8080:80 &
    PF_PID=$!
    sleep 3
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 > /dev/null 2>&1; then
      echo -e "${GREEN}[OK]${NC} WordPress está acessível via port-forward em http://localhost:8080"
      echo "Use este comando para acessar: kubectl port-forward svc/wordpress 8080:80"
    else
      echo -e "${RED}[FALHA]${NC} Não foi possível acessar o WordPress via port-forward"
    fi
    kill $PF_PID 2>/dev/null
  fi
else
  print_info "Entrada wordpress.local não encontrada no arquivo /etc/hosts"
  print_info "Para acessar o WordPress, use: kubectl port-forward svc/wordpress 8080:80"
fi

print_section "Recursos Utilizados"
echo "Uso de CPU e Memória dos Pods:"
kubectl top pods 2>/dev/null || echo "Métrica server não está habilitado no K3s por padrão."

print_section "Acesso via Killercoda"
echo "Para acessar o WordPress no Killercoda:"
echo "1. Clique no ícone '+' no topo do terminal"
echo "2. Selecione 'Traffic / Ports'"
echo "3. Digite a porta 80 e clique em 'Access'"
echo "Ou execute o comando: kubectl port-forward svc/wordpress 8080:80"

echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}===               STATUS VERIFICADO                ===${NC}"
echo -e "${GREEN}======================================================${NC}" 