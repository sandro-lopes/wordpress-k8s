# Provisionamento de WordPress com MySQL em Kubernetes

Este projeto oferece uma solução completa para provisionar WordPress com MySQL em um ambiente Kubernetes, garantindo persistência de dados e resiliência.

## Visão Geral da Solução

A solução implementa:

1. **Persistência de Dados**: Utiliza PersistentVolumeClaims para garantir que os dados do WordPress e MySQL persistam mesmo se os pods forem destruídos
2. **Configuração Segura**: Gerencia credenciais do banco de dados via Secrets do Kubernetes
3. **Exposição do Serviço**: Configura Ingress para acessar o WordPress externamente
4. **Recursos Limitados**: Define limites de recursos para garantir a estabilidade do ambiente
5. **Infraestrutura como Código**: Disponibiliza configurações em Terraform para automatizar o provisionamento
6. **Scripts de Automação**: Scripts para implantação, verificação de status e limpeza da aplicação

## Estrutura do Projeto

O projeto está organizado da seguinte forma:

```
├── kubernetes/          # Arquivos de configuração Kubernetes
│   ├── mysql-*.yaml     # Configurações do MySQL
│   └── wordpress-*.yaml # Configurações do WordPress
├── terraform/           # Arquivos de configuração Terraform
├── scripts/             # Scripts de automação
│   ├── deploy.sh        # Script para implantar a aplicação
│   ├── status.sh        # Script para verificar o status da aplicação
│   └── cleanup.sh       # Script para remover a aplicação
└── docs/                # Documentação adicional
```

## Pré-requisitos

- Ubuntu Linux (testado em uma VM Killercoda)
- Acesso de administrador (sudo)
- Conexão à internet

## Instalação do MicroK8s

### Passo 1: Instalar MicroK8s

```bash
# Atualizar pacotes
sudo apt update

# Instalar Snap
sudo apt install -y snapd

# Instalar MicroK8s
sudo snap install microk8s --classic --channel=1.27

# Adicionar usuário ao grupo microk8s
sudo usermod -a -G microk8s $USER
sudo chown -f -R $USER ~/.kube

# Recarregar grupos (ou reiniciar a sessão)
newgrp microk8s
```

### Passo 2: Configurar MicroK8s

```bash
# Verificar status do MicroK8s
microk8s status --wait-ready

# Habilitar plugins necessários
microk8s enable dns storage ingress
```

### Passo 3: Configurar acesso ao kubectl

```bash
# Criar diretório .kube se não existir
mkdir -p ~/.kube

# Gerar e salvar a configuração
microk8s config > ~/.kube/config

# Verificar acesso
microk8s kubectl get nodes
```

## Implantação do WordPress e MySQL

### Opção 1: Usando o Script de Implantação

A maneira mais fácil de implantar a aplicação é usando o script de implantação automatizada:

```bash
# Clonar o repositório ou copiar os arquivos
git clone <url-do-repositorio> wordpress-k8s
cd wordpress-k8s

# Tornar o script executável
chmod +x scripts/deploy.sh

# Executar o script de implantação
./scripts/deploy.sh
```

O script irá:
- Verificar se o MicroK8s está instalado
- Habilitar os plugins necessários
- Configurar o kubectl
- Implantar o MySQL e aguardar até que esteja pronto
- Implantar o WordPress e aguardar até que esteja pronto
- Configurar o acesso ao WordPress

### Opção 2: Aplicação direta com kubectl

```bash
# Clonar o repositório ou copiar os arquivos
git clone <url-do-repositorio> wordpress-k8s
cd wordpress-k8s

# Aplicar os arquivos de configuração do MySQL
microk8s kubectl apply -f kubernetes/mysql-pvc.yaml
microk8s kubectl apply -f kubernetes/mysql-secret.yaml
microk8s kubectl apply -f kubernetes/mysql-deployment.yaml
microk8s kubectl apply -f kubernetes/mysql-service.yaml

# Esperar o MySQL estar pronto
microk8s kubectl wait --for=condition=ready pod -l app=wordpress,tier=mysql --timeout=300s

# Aplicar os arquivos de configuração do WordPress
microk8s kubectl apply -f kubernetes/wordpress-pvc.yaml
microk8s kubectl apply -f kubernetes/wordpress-deployment.yaml
microk8s kubectl apply -f kubernetes/wordpress-service.yaml
microk8s kubectl apply -f kubernetes/wordpress-ingress.yaml

# Esperar o WordPress estar pronto
microk8s kubectl wait --for=condition=ready pod -l app=wordpress,tier=frontend --timeout=300s
```

### Opção 3: Implantação com Terraform

```bash
# Instalar Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt update && sudo apt install terraform

# Navegar até o diretório do Terraform
cd terraform

# Inicializar o Terraform
terraform init

# Verificar o plano
terraform plan

# Aplicar a configuração
terraform apply -auto-approve
```

## Acessando o WordPress

### Configurar arquivo hosts

Para acessar o WordPress pelo nome de domínio configurado, adicione a seguinte entrada ao arquivo `/etc/hosts`:

```
# Obter o IP do serviço Ingress
INGRESS_IP=$(microk8s kubectl get svc -n ingress -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')

# Se o comando acima não retornar um IP, usar o IP do nó
if [ -z "$INGRESS_IP" ]; then
  INGRESS_IP=$(hostname -I | awk '{print $1}')
fi

# Adicionar ao /etc/hosts
echo "$INGRESS_IP wordpress.local" | sudo tee -a /etc/hosts
```

### Acesse o WordPress no navegador

Abra o navegador e acesse:
- http://wordpress.local

Você verá a página de configuração inicial do WordPress:

![Tela inicial do WordPress](docs/images/wordpress_setup.png)

Complete a configuração com as informações desejadas para finalizar a instalação.

## Verificação do Status

Para verificar o status da aplicação, use o script de verificação de status:

```bash
# Tornar o script executável
chmod +x scripts/status.sh

# Executar o script de verificação de status
./scripts/status.sh
```

O script irá exibir informações detalhadas sobre todos os recursos relacionados à aplicação, incluindo:
- Status dos pods
- Status dos serviços
- Status do Ingress
- Status dos volumes persistentes
- Status dos secrets
- Status dos deployments
- Logs dos pods
- Acessibilidade do WordPress
- Recursos utilizados

## Validação da Solução

### Testar a resiliência

Para validar que os dados persistem mesmo quando os pods são destruídos:

```bash
# Fazer uma configuração inicial no WordPress
# (Acesse pelo navegador e configure um site básico)

# Simular uma falha no pod do WordPress
microk8s kubectl delete pod -l app=wordpress,tier=frontend

# Esperar a recriação automática
microk8s kubectl wait --for=condition=ready pod -l app=wordpress,tier=frontend --timeout=300s

# Verificar se as configurações persistiram
# (Acesse novamente pelo navegador)

# Simular uma falha no pod do MySQL
microk8s kubectl delete pod -l app=wordpress,tier=mysql

# Esperar a recriação automática
microk8s kubectl wait --for=condition=ready pod -l app=wordpress,tier=mysql --timeout=300s

# Verificar se os dados persistiram
# (Acesse o WordPress pelo navegador e verifique se o conteúdo ainda existe)
```

## Limpeza

Para remover os recursos, use o script de limpeza:

```bash
# Tornar o script executável
chmod +x scripts/cleanup.sh

# Executar o script de limpeza
./scripts/cleanup.sh
```

O script irá:
- Remover os recursos do WordPress
- Remover os recursos do MySQL
- Perguntar se deseja remover os volumes persistentes
- Perguntar se deseja remover a entrada do arquivo hosts

Alternativamente, você pode remover os recursos manualmente:

```bash
# Via kubectl
microk8s kubectl delete -f kubernetes/wordpress-ingress.yaml
microk8s kubectl delete -f kubernetes/wordpress-service.yaml
microk8s kubectl delete -f kubernetes/wordpress-deployment.yaml
microk8s kubectl delete -f kubernetes/wordpress-pvc.yaml
microk8s kubectl delete -f kubernetes/mysql-service.yaml
microk8s kubectl delete -f kubernetes/mysql-deployment.yaml
microk8s kubectl delete -f kubernetes/mysql-secret.yaml
microk8s kubectl delete -f kubernetes/mysql-pvc.yaml

# OU via Terraform
cd terraform
terraform destroy -auto-approve
```

## Solução de Problemas

### Verificando logs

```bash
# Logs do pod MySQL
microk8s kubectl logs -l app=wordpress,tier=mysql

# Logs do pod WordPress
microk8s kubectl logs -l app=wordpress,tier=frontend
```

### Verificando descrição dos recursos

```bash
# Descrever pod MySQL
microk8s kubectl describe pod -l app=wordpress,tier=mysql

# Descrever pod WordPress
microk8s kubectl describe pod -l app=wordpress,tier=frontend
```

### Problemas comuns

1. **WordPress não consegue conectar ao MySQL**:
   - Verifique se o serviço MySQL está funcionando corretamente
   - Verifique se as credenciais no Secret estão corretas

2. **Ingress não funciona**:
   - Verifique se o plugin de ingress está habilitado (`microk8s enable ingress`)
   - Verifique se o host está configurado corretamente no arquivo hosts

3. **Volumes persistentes não são criados**:
   - Verifique se o plugin de storage está habilitado (`microk8s enable storage`)

## Arquitetura da Solução

A solução implementa a seguinte arquitetura:

```
                   ┌─────────────┐
                   │   Ingress   │
                   │  Controller │
                   └──────┬──────┘
                          │
                          ▼
┌───────────────────────────────────────┐
│            WordPress Pod               │
│  ┌─────────────────────────────────┐  │
│  │          WordPress              │  │
│  └─────────────────────────────────┘  │
│  ┌─────────────────────────────────┐  │
│  │   Persistent Volume (10Gi)      │  │
│  └─────────────────────────────────┘  │
└─────────────────┬─────────────────────┘
                  │
                  ▼
┌───────────────────────────────────────┐
│              MySQL Pod                 │
│  ┌─────────────────────────────────┐  │
│  │             MySQL               │  │
│  └─────────────────────────────────┘  │
│  ┌─────────────────────────────────┐  │
│  │    Persistent Volume (5Gi)      │  │
│  └─────────────────────────────────┘  │
└───────────────────────────────────────┘
```

## Conclusão

Esta solução fornece um ambiente WordPress completo e resiliente usando Kubernetes, garantindo que:

1. Os dados do WordPress persistam mesmo em caso de falha nos pods
2. O banco de dados MySQL seja usado exclusivamente pelo WordPress
3. O time de Marketing Digital possa configurar o site sem preocupações com a infraestrutura
4. A solução esteja de acordo com os padrões da empresa usando Kubernetes 