# Guia de Instalação: WordPress + MySQL no Kubernetes

Este documento fornece instruções detalhadas para instalar e configurar o WordPress com MySQL no Kubernetes utilizando K3s em uma VM Ubuntu (Killercoda).

## Instalação Passo a Passo

### 1. Acessar e Utilizar o Killercoda

Killercoda é uma plataforma interativa baseada em navegador que oferece ambientes temporários para experimentar tecnologias como Kubernetes.

#### 1.1 Acessar o Killercoda

1. Abra seu navegador e acesse [https://killercoda.com/](https://killercoda.com/)

2. Efetue o login com sua conta ou com a conta de um dos provedores listados. Ex: GutHub, Google, GitLab etc.

3. Selecione a opção "Playgrounds" e, em seguida, "Ubuntu 24.04". 

4. Clique em "START" para iniciar o ambiente Ubuntu.

#### 1.2 Utilizando o Terminal

- O terminal já está pronto para uso, sem necessidade de login.
- Você tem acesso de administrador (sudo) por padrão.
- O terminal é um ambiente Ubuntu completo com acesso à internet.
- O ambiente permanece ativo por aproximadamente 1 hora.
- **Importante**: Ao final da sessão, todos os dados serão perdidos, então é recomendável salvar qualquer configuração importante.

#### 1.3 Verificando o Ambiente

Execute os seguintes comandos para verificar o ambiente:

```bash
# Verificar espaço em disco disponível
df -h

# Verificar memória disponível
free -h
```

#### 1.4 Considerações Importantes

- **Duração Limitada**: O ambiente Killercoda expira após aproximadamente 1 hora de uso.
- **Recursos Limitados**: O ambiente tem recursos limitados, mas suficientes para este projeto.
- **Dados Temporários**: Todos os dados e configurações são temporários e serão perdidos quando a sessão expirar.
- **Conectividade**: Você precisará manter a janela do navegador aberta durante todo o processo.
- **Acesso Externo**: Killercoda oferece a possibilidade de expor portas para acesso externo, o que usaremos para acessar o WordPress.


### 2. Preparação do Ambiente

Primeiramente, vamos preparar o ambiente Ubuntu com as ferramentas necessárias:

```bash
# Atualizar a lista de pacotes
sudo apt update

# Instalar ferramentas básicas
sudo apt install -y curl wget git unzip
```

### 3. Instalação do K3s

K3s é uma distribuição leve do Kubernetes ideal para ambientes como o Killercoda:

```bash
# Instalar K3s (servidor Kubernetes leve)
curl -sfL https://get.k3s.io | sh -

# Aguardar até que o K3s esteja pronto
sleep 10
sudo k3s kubectl get nodes

# Verificar status do serviço K3s
sudo systemctl status k3s
```

### 4. Configurar o kubectl

```bash
# Criar diretório .kube se não existir
mkdir -p ~/.kube

# Copiar e configurar o arquivo de configuração do K3s
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
export KUBECONFIG=~/.kube/config

# Verificar se o kubectl está funcionando corretamente
kubectl get nodes
```

### 5. Baixar os Arquivos de Configuração

```bash
# Clonar o repositório (ou copiar manualmente os arquivos)
git clone <url-do-repositorio> wordpress-k8s
cd wordpress-k8s
```

### 6. Método Simplificado: Usar o Script de Implantação

A maneira mais fácil de implantar todo o ambiente é usando o script de implantação fornecido:

```bash
# Tornar o script executável
chmod +x scripts/deploy.sh

# Executar o script de implantação
./scripts/deploy.sh
```

O script irá automaticamente:
- Verificar se o K3s está instalado e configurado corretamente
- Implantar o MySQL e aguardar até que esteja pronto
- Implantar o WordPress e aguardar até que esteja pronto
- Ajudar a configurar o acesso ao WordPress

**Nota**: Se você estiver usando os scripts originais projetados para MicroK8s, poderá ser necessário adaptá-los para K3s. Veremos como fazer isso mais adiante.

Se preferir realizar a implantação manualmente, siga os passos 7 a 10 abaixo.

### 7. Implantar o MySQL

Primeiro, implantaremos o MySQL que servirá como banco de dados para o WordPress:

```bash
# Aplicar o PersistentVolumeClaim para armazenamento persistente
kubectl apply -f kubernetes/mysql-pvc.yaml

# Aplicar o Secret para as credenciais do banco de dados
kubectl apply -f kubernetes/mysql-secret.yaml

# Aplicar o Deployment do MySQL
kubectl apply -f kubernetes/mysql-deployment.yaml

# Aplicar o Service do MySQL
kubectl apply -f kubernetes/mysql-service.yaml

# Aguardar até que o pod do MySQL esteja pronto
kubectl wait --for=condition=ready pod -l app=wordpress,tier=mysql --timeout=300s
```

### 8. Implantar o WordPress

Agora, implantaremos o WordPress que se conectará ao MySQL:

```bash
# Aplicar o PersistentVolumeClaim para armazenamento persistente
kubectl apply -f kubernetes/wordpress-pvc.yaml

# Aplicar o Deployment do WordPress
kubectl apply -f kubernetes/wordpress-deployment.yaml

# Aplicar o Service do WordPress
kubectl apply -f kubernetes/wordpress-service.yaml

# Aplicar o Ingress para expor o WordPress externamente
kubectl apply -f kubernetes/wordpress-ingress.yaml

# Aguardar até que o pod do WordPress esteja pronto
kubectl wait --for=condition=ready pod -l app=wordpress,tier=frontend --timeout=300s
```

### 9. Configurar o Acesso ao WordPress

Para acessar o WordPress, precisamos configurar o arquivo hosts:

```bash
# Obter o IP do serviço Ingress (para K3s)
INGRESS_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')

# Adicionar a entrada ao arquivo hosts
echo "$INGRESS_IP wordpress.local" | sudo tee -a /etc/hosts

# Verificar se a entrada foi adicionada corretamente
cat /etc/hosts
```

#### 9.1 Acessando o WordPress na Killercoda

Quando estiver usando o Killercoda, você precisa utilizar a funcionalidade de exposição de portas:

1. Na interface do Killercoda, clique no ícone de "+" no topo do terminal
2. Selecione a opção "Traffic / Ports"
3. Insira a porta 80 e clique em "Access"
4. Uma nova aba será aberta com o WordPress

Alternativamente, você também pode acessar via linha de comando:

```bash
# Verificar se o Ingress está funcionando
kubectl get ingress

# Se necessário, expor o serviço diretamente
kubectl port-forward svc/wordpress 8080:80
```

### 10. Acessar o WordPress

Agora você pode acessar o WordPress pelo navegador:

1. Abra o navegador e acesse: http://wordpress.local (ou através da porta exposta na Killercoda)
2. Você verá a tela de configuração inicial do WordPress
3. Complete as informações solicitadas:
   - Título do site: Site da Empresa
   - Nome de usuário: admin
   - Senha: (escolha uma senha forte)
   - E-mail: seu-email@empresa.com
4. Clique em "Instalar WordPress"

## Verificação do Status da Aplicação

Para verificar facilmente o status da sua aplicação, use o script de verificação:

```bash
# Tornar o script executável
chmod +x scripts/status.sh

# Executar o script
./scripts/status.sh
```

**Nota**: Se o script de status.sh foi originalmente escrito para MicroK8s, você precisará modificá-lo para usar o kubectl padrão em vez de microk8s kubectl.

## Adaptação dos Scripts para K3s

Se você baixou scripts originalmente projetados para o MicroK8s, será necessário adaptá-los para K3s:

```bash
# Editar o script de implantação
sed -i 's/microk8s kubectl/kubectl/g' scripts/deploy.sh
sed -i 's/microk8s status/sudo systemctl status k3s/g' scripts/deploy.sh

# Editar o script de status
sed -i 's/microk8s kubectl/kubectl/g' scripts/status.sh

# Editar o script de limpeza
sed -i 's/microk8s kubectl/kubectl/g' scripts/cleanup.sh
```

## Teste de Resiliência

Vamos verificar se nossa solução é resiliente:

```bash
# Obter o nome do pod do WordPress
WORDPRESS_POD=$(kubectl get pod -l app=wordpress,tier=frontend -o jsonpath='{.items[0].metadata.name}')

# Deletar o pod para simular uma falha
kubectl delete pod $WORDPRESS_POD

# Verificar que um novo pod é criado automaticamente
kubectl get pods -w

# Quando o novo pod estiver pronto, acesse novamente o WordPress no navegador
# http://wordpress.local

# Todas as configurações devem estar preservadas!
```

Faça o mesmo teste com o MySQL:

```bash
# Obter o nome do pod do MySQL
MYSQL_POD=$(kubectl get pod -l app=wordpress,tier=mysql -o jsonpath='{.items[0].metadata.name}')

# Deletar o pod para simular uma falha
kubectl delete pod $MYSQL_POD

# Verificar que um novo pod é criado automaticamente
kubectl get pods -w

# Quando o novo pod estiver pronto, acesse novamente o WordPress no navegador
# http://wordpress.local

# O site deve continuar funcionando e os dados devem estar preservados!
```

## Usando o Terraform (Opcional)

Se preferir usar Terraform para gerenciar a infraestrutura:

```bash
# Instalar Terraform
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install -y terraform

# Navegar até o diretório do Terraform
cd terraform

# Inicializar o Terraform
terraform init

# Verificar o plano de execução
terraform plan

# Aplicar a configuração
terraform apply -auto-approve
```

**Nota**: Os arquivos Terraform também podem precisar de ajustes se foram escritos especificamente para MicroK8s.

## Limpeza da Aplicação

Para remover os recursos, use o script de limpeza:

```bash
# Tornar o script executável
chmod +x scripts/cleanup.sh

# Executar o script de limpeza
./scripts/cleanup.sh
```

O script irá perguntar se você deseja remover os volumes persistentes (que contêm os dados) e a entrada no arquivo hosts.

Alternativamente, você pode remover os recursos manualmente:

```bash
# Via kubectl
kubectl delete -f kubernetes/wordpress-ingress.yaml
kubectl delete -f kubernetes/wordpress-service.yaml
kubectl delete -f kubernetes/wordpress-deployment.yaml
kubectl delete -f kubernetes/wordpress-pvc.yaml
kubectl delete -f kubernetes/mysql-service.yaml
kubectl delete -f kubernetes/mysql-deployment.yaml
kubectl delete -f kubernetes/mysql-secret.yaml
kubectl delete -f kubernetes/mysql-pvc.yaml
```

## Desinstalação do K3s (se necessário)

Se você quiser remover completamente o K3s do sistema:

```bash
# Desinstalar K3s
/usr/local/bin/k3s-uninstall.sh
```

## Conclusão

Parabéns! Você agora tem um ambiente WordPress completo e resiliente rodando no Kubernetes usando K3s. O time de Marketing Digital pode usar este ambiente para configurar o site da empresa, com a garantia de que os dados estarão seguros e o ambiente é resistente a falhas.

Lembre-se que esta é uma solução empresarial que segue as melhores práticas:
- Utiliza Kubernetes como plataforma de orquestração
- Implementa persistência de dados para garantir que nenhuma configuração seja perdida
- Configura recursos de forma limitada para garantir estabilidade
- Fornece mecanismos para monitoramento e resolução de problemas 