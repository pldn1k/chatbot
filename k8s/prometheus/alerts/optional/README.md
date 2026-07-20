# ⚠️ Опциональные алерты

Эти алерты требуют дополнительной настройки метрик в вашем кластере.

## Как включить

1. Установите соответствующие экспортеры метрик:
   - Для `chatbot.yml`: настройте `ServiceMonitor` для вашего приложения
   - Для `postgresql.yml`: включите `postgres-exporter`
   - Для `rabbitmq.yml`: включите `rabbitmq-prometheus`
   - Для `redis.yml`: включите `redis-exporter`

2. Убедитесь, что метрики доступны в Prometheus

3. Скопируйте файлы из `optional/` в родительскую папку:
   ```bash
   cp optional/*.yml .
