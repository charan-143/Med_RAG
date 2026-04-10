import os
from dotenv import load_dotenv

# Load from .env if exists, else load from .env.example
if os.path.exists(".env"):
    load_dotenv(".env")
else:
    load_dotenv(".env.example")

class Settings:
    PROJECT_NAME = "Medical RAG API"
    LANCEDB_URI = os.getenv("LANCEDB_URI") or "data/process_cache/vectordb"
    GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY", "").strip()

settings = Settings()
