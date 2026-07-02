import os
from pydantic_settings import BaseSettings
from sqlmodel import create_engine, Session


class Settings(BaseSettings):
    database_url: str = "postgresql://healthtracker:password@localhost:5432/healthtracker"
    jwt_secret: str = "your_jwt_secret_min_32_chars_long_key_here"
    openrouter_api_key: str = ""
    groq_api_key: str = ""
    n8n_webhook_url: str = "http://localhost:5678/webhook"
    
    class Config:
        env_file = ".env"


settings = Settings()

engine = create_engine(settings.database_url, echo=False)


def get_session():
    with Session(engine) as session:
        yield session