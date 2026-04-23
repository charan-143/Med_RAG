"""
Clinical Atelier — FastAPI application entry point.
"""

from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from api.routes_vault    import router as vault_router
from api.routes_chat     import router as chat_router
from api.routes_notebook import router as notebook_router
from api.routes_profile  import router as profile_router
from db.sqlite_db        import init_db


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Run startup tasks (DB init) then yield for the app lifetime."""
    init_db()
    yield


app = FastAPI(
    title="Clinical Atelier — Medical RAG API",
    description="Backend for the Clinical Atelier patient records RAG system.",
    version="2.0.0",
    lifespan=lifespan,
)

# ── CORS — allow Flutter app (restrict origins in production) ──────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── API routes ─────────────────────────────────────────────────────────────────
app.include_router(vault_router,    prefix="/api")
app.include_router(chat_router,     prefix="/api")
app.include_router(notebook_router, prefix="/api")
app.include_router(profile_router,  prefix="/api")


