import redis.asyncio as redis
import json
import os

redis_client = redis.Redis(
    host=os.getenv("REDIS_HOST", "redis"),
    port=int(os.getenv("REDIS_PORT", 6379)),
    password=os.getenv("REDIS_PASSWORD", ""),
    decode_responses=True
)

async def get_cached_response(message: str):
    return await redis_client.get(f"chat:cache:{message}")
    
async def set_cached_response(message: str, response: str, ttl=3600):
    await redis_client.setex(f"chat:cache:{message}", ttl ,response)
