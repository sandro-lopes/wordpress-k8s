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
git clone https://github.com/sandro-lopes/wordpress-k8s.git
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

Durante a execução do script de implantação, você receberá a seguinte mensagem:

```
Você precisa adicionar a seguinte entrada ao seu arquivo /etc/hosts:
172.30.1.2 wordpress.local
Deseja adicionar automaticamente ao /etc/hosts? (s/n): s
```

É importante responder "s" para que o script possa adicionar automaticamente a entrada necessária ao arquivo `/etc/hosts`.

#### 6.1 Acessando o WordPress no ambiente Killercoda

Para acessar o WordPress no ambiente Killercoda, use o seguinte método (NodePort):

```bash
# Configurar o serviço WordPress como NodePort 
kubectl patch svc wordpress -p '{"spec":{"type":"NodePort"}}'

# Verificar em qual porta o serviço está exposto
kubectl get svc wordpress
```

Você verá algo como `80:32XXX/TCP` na coluna PORT(S), onde 32XXX é a porta NodePort atribuída automaticamente.

Para acessar o WordPress:

1. Clique no ícone "hambúrguer" no topo à direita do terminal (ao lado do tempo restante de utilização)
2. Selecione "Traffic / Ports"
3. Digite a porta NodePort (32XXX) que foi atribuída e clique em "Access"
4. Uma nova aba será aberta com o WordPress funcionando


### 7. Implantar o MySQL

Se você usou o script de implantação (seção 6), pode pular as seções 7 e 8, pois elas já foram executadas automaticamente.

Se preferir realizar a implantação manualmente:

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

Continuando a implantação manual:

```bash
# Aplicar o PersistentVolumeClaim para armazenamento persistente
kubectl apply -f kubernetes/wordpress-pvc.yaml

# Aplicar o Deployment do WordPress
kubectl apply -f kubernetes/wordpress-deployment.yaml

# Aplicar o Service do WordPress (configurado como NodePort)
kubectl apply -f kubernetes/wordpress-service.yaml
kubectl patch svc wordpress -p '{"spec":{"type":"NodePort"}}'

# Aguardar até que o pod do WordPress esteja pronto
kubectl wait --for=condition=ready pod -l app=wordpress,tier=frontend --timeout=300s

# Verificar em qual porta o NodePort está exposto
kubectl get svc wordpress
```

### 9. Acessar o WordPress

Agora você pode acessar o WordPress pelo navegador:

1. Obtenha a porta NodePort exposta:
   ```bash
   kubectl get svc wordpress
   ```
   Observe o número da porta na coluna PORT(S) - será algo como `80:32XXX/TCP`

2. No Killercoda:
   - Clique no ícone "hambúrguer" no topo à direita do terminal
   - Selecione "Traffic / Ports"
   - Digite a porta NodePort (32XXX) que foi atribuída
   - Clique em "Access"

3. Na tela de configuração, complete as informações solicitadas:
   - Título do site: Site da Empresa
   - Nome de usuário: admin
   - Senha: (escolha uma senha forte)
   - E-mail: seu-email@empresa.com

4. Clique em "Instalar WordPress"

5. Após a instalação, você será redirecionado para a tela de login:
   - Faça login com o usuário e senha que você acabou de configurar
   - Você será direcionado para o painel de administração do WordPress

**Nota**: Se você encontrar problemas de acesso:
- Verifique se o pod do WordPress está pronto usando `kubectl get pods`
- Verifique os logs usando `kubectl logs -l app=wordpress,tier=frontend`
- Certifique-se de que está usando a porta NodePort correta

## Verificação do Status da Aplicação

Para verificar facilmente o status da sua aplicação, use o script de verificação:

```bash
# Tornar o script executável
chmod +x scripts/status.sh

# Executar o script
./scripts/status.sh
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

# Quando o novo pod estiver pronto, acesse novamente o WordPress pelo navegador
# usando a mesma porta NodePort de antes

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

# Quando o novo pod estiver pronto, acesse novamente o WordPress pelo navegador
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


## Conclusão
Esta solução fornece um ambiente WordPress completo e resiliente usando Kubernetes, garantindo que:

1. Os dados do WordPress persistam mesmo em caso de falha nos pods
2. O banco de dados MySQL seja usado exclusivamente pelo WordPress
3. O time de Marketing Digital possa configurar o site sem preocupações com a infraestrutura
4. A solução esteja de acordo com os padrões da empresa usando Kubernetes 