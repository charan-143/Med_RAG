from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
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

# Register routes
app.include_router(upload_router, prefix="/api")
app.include_router(chat_router, prefix="/api")

@app.get("/")
def read_root():
    return {"message": "Welcome to the Medical RAG API! Endpoints are at /api/upload and /api/chat"}
