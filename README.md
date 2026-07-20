# Corporate Chatbot on Kubernetes

Корпоративный чат-бот на FastAPI с полным observability стеком, работающий в Kubernetes.

## 🚀 Быстрый старт

### Требования
- Docker
- kubectl
- Helm
- Kind (или любой другой Kubernetes кластер)

### Установка одной командой

```bash
# 1. Клонируйте репозиторий
git clone https://github.com/your-username/chatbot-project.git
cd chatbot-project

# 2. Запустите деплой
chmod +x scripts/deploy.sh
./scripts/deploy.sh

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
