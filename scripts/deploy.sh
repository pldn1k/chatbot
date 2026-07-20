#!/bin/bash
set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🚀 Deploying Chatbot to Kubernetes...${NC}"

# ============================================
# 1. Проверка зависимостей
# ============================================
echo -e "${YELLOW}📦 Checking dependencies...${NC}"
command -v docker >/dev/null 2>&1 || { echo -e "${RED}❌ Docker not found${NC}"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}❌ kubectl not found${NC}"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo -e "${RED}❌ Helm not found${NC}"; exit 1; }
command -v kind >/dev/null 2>&1 || { echo -e "${RED}❌ Kind not found${NC}"; exit 1; }

# ============================================
# 2. Сборка Docker образа
# ============================================
echo -e "${YELLOW}🐳 Building Docker image...${NC}"
docker build -f docker/Dockerfile -t chatbot:latest .

# ============================================
# 3. Проверка/создание Kind кластера
# ============================================
echo -e "${YELLOW}☸️ Checking Kind cluster...${NC}"
if ! kind get clusters 2>/dev/null | grep -q kind; then
    echo -e "${YELLOW}Creating Kind cluster...${NC}"
    kind create cluster --config=kind-config.yaml
else
    echo -e "${GREEN}✅ Kind cluster already exists${NC}"
fi

# ============================================
# 4. Загрузка образа в Kind
# ============================================
echo -e "${YELLOW}📤 Loading image into Kind...${NC}"
kind load docker-image chatbot:latest --name kind

# ============================================
# 5. Установка Ingress Controller
# ============================================
echo -e "${YELLOW}🌐 Installing NGINX Ingress Controller...${NC}"
helm repo add nginx-stable https://helm.nginx.com/stable 2>/dev/null || true
helm repo update

if helm list -n ingress-nginx 2>/dev/null | grep -q ingress-nginx; then
    echo -e "${GREEN}✅ Ingress Controller already installed${NC}"
else
    echo -e "${YELLOW}Installing Ingress Controller...${NC}"
    helm install ingress-nginx nginx-stable/nginx-ingress \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.service.type=NodePort \
        --set controller.service.httpPort.nodePort=30080 \
        --set controller.service.httpsPort.nodePort=30443
fi

# ============================================
# 6. Установка PostgreSQL (если нет)
# ============================================
echo -e "${YELLOW}🗄️ Checking PostgreSQL...${NC}"
if helm list -n chatbot 2>/dev/null | grep -q postgresql; then
    echo -e "${GREEN}✅ PostgreSQL already installed${NC}"
else
    echo -e "${YELLOW}Installing PostgreSQL...${NC}"
    helm upgrade --install postgresql bitnami/postgresql \
        --namespace chatbot \
        --create-namespace \
        --set auth.username=chatbot_user \
        --set auth.password=secure_password \
        --set auth.database=chatbot \
        --wait
fi

# ============================================
# 7. Установка Redis (если нет)
# ============================================
echo -e "${YELLOW}🔴 Checking Redis...${NC}"
if helm list -n chatbot 2>/dev/null | grep -q redis; then
    echo -e "${GREEN}✅ Redis already installed${NC}"
else
    echo -e "${YELLOW}Installing Redis...${NC}"
    helm upgrade --install redis bitnami/redis \
        --namespace chatbot \
        --set auth.password=redis_password \
        --set master.persistence.enabled=false \
        --wait
fi

# ============================================
# 8. Установка RabbitMQ из манифеста
# ============================================
echo -e "${YELLOW}🐇 Installing RabbitMQ from manifest...${NC}"
kubectl apply -f k8s/rabbitmq/deployment.yaml

# Проверяем, что под запустился
sleep 10
kubectl get pods -n chatbot | grep rabbitmq

# ============================================
# 9. Установка Jaeger (если нет)
# ============================================
echo -e "${YELLOW}🔍 Checking Jaeger...${NC}"
helm repo add jaeger https://jaegertracing.github.io/helm-charts 2>/dev/null || true
helm repo update

if helm list -n chatbot 2>/dev/null | grep -q jaeger; then
    echo -e "${GREEN}✅ Jaeger already installed${NC}"
else
    echo -e "${YELLOW}Installing Jaeger...${NC}"
    helm upgrade --install jaeger jaeger/jaeger \
        --namespace chatbot \
        --set provisionDataStore.cassandra=false \
        --set provisionDataStore.elasticsearch=false \
        --set storage.type=memory \
        --set agent.enabled=true \
        --set agent.strategy=DaemonSet \
        --set query.service.type=ClusterIP \
        --set query.service.port=16686 \
        --wait
fi

# ============================================
# 10. Установка самого чатбота (если нет)
# ============================================
echo -e "${YELLOW}🤖 Checking Chatbot...${NC}"
if helm list -n chatbot 2>/dev/null | grep -q chatbot; then
    echo -e "${GREEN}✅ Chatbot already installed${NC}"
else
    echo -e "${YELLOW}Installing Chatbot...${NC}"
    helm upgrade --install chatbot ./helm/chatbot \
        --namespace chatbot \
        --set image.repository=chatbot \
        --set image.tag=latest \
        --set image.pullPolicy=IfNotPresent \
        --set postgresql.enabled=false \
        --set redis.enabled=false \
        --set rabbitmq.enabled=false \
        --wait
fi

# ============================================
# 11. Проверка статуса
# ============================================
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""
echo -e "${YELLOW}📊 Checking status...${NC}"
kubectl get pods -n chatbot
kubectl get pods -n ingress-nginx

echo ""
echo -e "${GREEN}🔗 Access URLs:${NC}"
echo "📡 API: kubectl port-forward svc/chatbot -n chatbot 8000:8000"
echo "🐇 RabbitMQ: kubectl port-forward svc/rabbitmq -n chatbot 15672:15672"
echo ""
echo -e "${YELLOW}💡 To test the API:${NC}"
echo "curl -X POST \"http://localhost:8000/chat?message=Hello&user_id=test\""
