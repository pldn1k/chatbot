from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from models import ChatMessage
from datetime import datetime, timedelta
from typing import List, Optional

async def save_message(
    db: AsyncSession,
    user_id: str,
    message: str,
    role: str
):
    new_message = ChatMessage(
        user_id=user_id,
        message=message,
        role=role,
        timestamp=datetime.utcnow()
    )
    db.add(new_message)
    await db.commit()
    await db.refresh(new_message)
    return new_message

async def get_chat_history(
    db: AsyncSession,
    user_id: str,
    limit: int = 50,
    offset: int = 0
):
    query = (
        select(ChatMessage)
        .where(ChatMessage.user_id == user_id)
        .order_by(desc(ChatMessage.timestamp))
        .limit(limit)
        .offset(offset)
    )
    result = await db.execute(query)
    return result.scalars().all()

async def get_recent_messages(
    db: AsyncSession,
    user_id: str,
    hours: int = 24
):
    cutoff_time = datetime.utcnow() - timedelta(hours=hours)
    query = (
        select(ChatMessage)
        .where(ChatMessage.user_id == user_id)
        .where(ChatMessage.timestamp >= cutoff_time)
        .order_by(ChatMessage.timestamp)
    )
    result = await db.execute(query)
    return result.scalars().all()

async def delete_user_history(
    db: AsyncSession,
    user_id: str
):
    query = select(ChatMessage).where(ChatMessage.user_id == user_id)
    result = await db.execute(query)
    messages = result.scalars().all()
    
    for msg in messages:
        await db.delete(msg)
    
    await db.commit()
    return len(messages)

async def get_all_users(db: AsyncSession):
    query = select(ChatMessage.user_id).distinct()
    result = await db.execute(query)
    return result.scalars().all()

async def get_message_stats(db: AsyncSession):
    total_query = select(ChatMessage)
    total_result = await db.execute(total_query)
    total = len(total_result.scalars().all())
    
    users = await get_all_users(db)
    
    return {
        "total_messages": total,
        "unique_users": len(users),
        "last_updated": datetime.utcnow().isoformat()
    }
