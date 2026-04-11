from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from api.routes_upload import router as upload_router
from api.routes_chat import router as chat_router

app = FastAPI(title="Medical RAG API")

# Configure CORS for frontend access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register API routes (must precede the static mount)
app.include_router(upload_router, prefix="/api")
app.include_router(chat_router, prefix="/api")

# Serve the beautifully styled Native Frontend
app.mount("/", StaticFiles(directory="static", html=True), name="static")
