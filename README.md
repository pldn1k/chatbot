# Corporate Chatbot on Kubernetes

Корпоративный чат-бот на FastAPI с полным observability стеком, работающий в Kubernetes.

## 🚀 Быстрый старт

### Требования
- Docker
- kubectl
- Helm
- Kind (или любой другой Kubernetes кластер)
- Self-hosted GitHub Actions Runner (для CI/CD)

### Установка 

```bash
# 1. Клонируйте репозиторий
git clone https://github.com/your-username/chatbot-project.git
cd chatbot

# 2. Запустите деплой
chmod +x scripts/deploy.sh
./scripts/deploy.sh

# 3/ Проверьте статус
kubectl get pods -n chatbot

### Пример запроса
curl -X POST "http://localhost:8000/chat?message=Hello&user_id=test"

Ответ:
json
{
  "response": "Echo: Hello",
  "source": "database"
}

### Архитектура

FastAPI — бэкенд

PostgreSQL — хранилище сообщений

Redis — кэширование

RabbitMQ — очереди

Jaeger — трейсинг

Grafana + Loki — логи и мониторинг

Kubernetes (Kind) — оркестрация

### Мониторинг

Сервис	        Доступ
Swagger UI	http://localhost:8000/docs
Grafana	        http://localhost:3000 (admin/admin)
Jaeger	        http://localhost:16686
RabbitMQ	http://localhost:15672 (guest/guest)
Prometheus	http://localhost:9090

### CI/CD
Проект использует GitHub Actions с self-hosted runner для автоматического деплоя:

1) При пуше в ветку main запускается workflow.

2) Собирается Docker образ и пушится в Docker Hub.

3) Выполняется helm upgrade --install для обновления приложения в кластере.

### Настройка self-hosted runner
mkdir actions-runner && cd actions-runner
curl -o actions-runner-linux-x64-2.335.1.tar.gz -L https://github.com/actions/runner/releases/download/v2.335.1/actions-runner-linux-x64-2.335.1.tar.gz
tar xzf ./actions-runner-linux-x64-2.335.1.tar.gz
./config.sh --url https://github.com/pldn1k/chatbot --token <YOUR_TOKEN>
./run.sh

### Удаление
kubectl delete namespace chatbot
kind delete cluster --name kind
