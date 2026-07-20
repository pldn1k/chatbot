import os
import logging
from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.ext.asyncio import AsyncSession
# from opentelemetry import trace
# from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
# from opentelemetry.exporter.jaeger.thrift import JaegerExporter
# from opentelemetry.sdk.trace import TracerProvider
# from opentelemetry.sdk.trace.export import BatchSpanProcessor

from models import init_db, get_db
from crud import save_message, get_chat_history
from cache import get_cached_response, set_cached_response
from rabbitmq_queue import publish_to_queue

# Настройка логирования
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Настройка трейсинга Jaeger
def setup_tracing():
    jaeger_exporter = JaegerExporter(
        agent_host_name=os.getenv("JAEGER_AGENT_HOST", "jaeger-agent"),
        agent_port=6831,
    )
    provider = TracerProvider()
    provider.add_span_processor(BatchSpanProcessor(jaeger_exporter))
    trace.set_tracer_provider(provider)

# setup_tracing()

app = FastAPI(title="Corporate Chatbot API", version="1.0.0")

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # в продакшене указывается конкретный домен
    allow_credentials=True, # разрешить куки
    allow_methods=["*"],
    allow_headers=["*"],
)

# Instrumentation для трейсинга. Автоматически оборачивает эндпоинты в спаны, добавляет хттп метаданные
# FastAPIInstrumentor.instrument_app(app)

# Эндпоинт для чата
@app.post("/chat")
async def chat_endpoint(
    message: str,
    user_id: str,
    db: AsyncSession = Depends(get_db)
): 
    # tracer = trace.get_tracer(__name__)   # Трейсинг внутри эндпоинта
    # with tracer.start_as_current_span("chat_process"):
        logger.info(f"User {user_id} sent: {message}")
        
        # Проверяем кэш
        cached = await get_cached_response(message)
        if cached:
            logger.info("Returning cached response")
            return {"response": cached, "source": "cache"}
            
        # Сохраняем запрос в БД
        await save_message(db, user_id, message, "user")
        
        # Отправляем в очередь для обработки (возращаем, что запрос обрабытывается, задача идет в очередь
        # Воркер забирает задачу, генерирует ответ. Пользователь получает уведомление, что ответ готов)
        await publish_to_queue(message, user_id)
        
        # Имитация ответа (в реально случае - вызов OpenAI API, обработка через NLP модель, поиск в векторной БД, вызов внешних сервисов)
        response = f"Echo: {message}"
        
        # Сохраняем ответ в БД
        await save_message(db, user_id, response, "bot")
        
        # Кэшируем. (порядок этих двух действий важен, чтобы не потерять данные, если БД упадёт
        await set_cached_response(message, response)
        
        return {"response": response, "source": "database"}
        
# Эндпоинт истории чата
@app.get("/history/{user_id}")
async def get_history(user_id: str, db: AsyncSession = Depends(get_db)):
    history = await get_chat_history(db, user_id)
    return {"user_id": user_id, "history": history}
    
# Health check для Kubernetes.Кубер каждые 10с стучится в Хелс - если ответа нет, контейнер перезапускается
@app.get("/health")
async def health_check():
    return {"status": "healthy"}
    
# Запуск при инициализации. Создаются таблицы в БД, если их нет. Логируется успешный старт
@app.on_event("startup")
async def startup_event():
    await init_db()
    logger.info("Application started successfully")
