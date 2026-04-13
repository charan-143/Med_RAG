# Clinical Atelier — Project Structure

```
Backend_1/                              ← Monorepo root (also the FastAPI project root)
│
├── main.py                             ← FastAPI app entry; registers all routers, runs init_db() on startup
├── pyproject.toml                      ← Python project + uv dependency manifest
├── uv.lock                             ← Locked dependency tree (uv)
├── .env                                ← Secret keys (GOOGLE_API_KEY, etc.) — never committed
├── .python-version                     ← Pinned Python version for uv
├── .gitignore                          ← Excludes .venv, .env, data/, uploads/, Flutter build artifacts
├── README.md                           ← Project overview and run instructions
│
├── core/                               ← App-wide shared utilities
│   ├── __init__.py
│   ├── config.py                       ← Pydantic Settings — loads .env, exposes settings object
│   └── exceptions.py                   ← Custom HTTP exception classes
│
├── agents/                             ← Agno multi-agent definitions
│   ├── __init__.py
│   ├── base_agent.py                   ← Factory: create_base_medical_agent() — shared model + instructions
│   ├── medical_agent.py                ← Standalone single-agent (legacy / unused path)
│   └── routing_agent.py                ← Supervisor Team: clinical_analyst + radiologist → medical_team_agent
│
├── api/                                ← FastAPI route modules
│   ├── __init__.py
│   ├── dependencies.py                 ← DI provider: get_medical_team_router() → Team
│   ├── routes_chat.py                  ← POST /chat, GET /chat/history — RAG chat with vault context
│   ├── routes_vault.py                 ← Folders, Files, Upload, Preview, GET /overview/stats
│   ├── routes_notebook.py              ← Clinical notes CRUD + POST /notes/save-insight
│   ├── routes_profile.py               ← GET/PUT patient profile
│   └── routes_upload.py                ← Legacy upload route (pre-vault; kept for compatibility)
│
├── models/                             ← Data schemas
│   ├── __init__.py
│   ├── api_models.py                   ← Pydantic request/response models (FileRecord, NoteOut, ChatResponse …)
│   └── db_models.py                    ← Low-level DB row type hints (internal use)
│
├── db/                                 ← Database layer
│   ├── __init__.py
│   ├── sqlite_db.py                    ← SQLite: tables (files, folders, notes, chat_history, profile), init + CRUD helpers
│   ├── vector_store.py                 ← LanceDB + GeminiEmbedder knowledge base for RAG
│   └── mongodb.py                      ← Unused MongoDB stub (reserved for future cloud sync)
│
├── services/                           ← Business-logic helpers
│   ├── __init__.py
│   ├── document_parser.py              ← PDF text extraction helper (used before indexing)
│   └── image_processor.py              ← Converts uploaded images to agno Image objects for vision agents
│
├── static/                             ← Legacy HTML frontend (pre-Flutter)
│   ├── index.html                      ← Old single-page UI
│   ├── script.js                       ← Old vanilla-JS chat handler
│   └── style.css                       ← Old styles
│
├── data/                               ← Runtime data (gitignored)
│   ├── clinical_atelier.db             ← SQLite database file
│   ├── clinical_atelier.db-shm         ← SQLite shared-memory WAL index
│   ├── clinical_atelier.db-wal         ← SQLite write-ahead log
│   ├── uploads/                        ← Uploaded patient files (UUID filenames)
│   └── process_cache/                  ← LanceDB vector index + embeddings
│
└── med_rag_flutter/                    ← Flutter frontend (Clinical Atelier UI)
    │
    ├── pubspec.yaml                    ← Flutter dependencies (http, google_fonts, file_picker …)
    ├── pubspec.lock                    ← Locked Flutter dependency tree
    ├── analysis_options.yaml           ← Dart linter config
    │
    ├── lib/                            ← All Dart source code
    │   ├── main.dart                   ← App entry: MaterialApp → AppTheme → ShellScreen
    │   │
    │   ├── core/                       ← Shared design system + services
    │   │   ├── theme.dart              ← AppColors, AppTextStyles, AppRadius, AppTheme
    │   │   └── api_service.dart        ← HTTP client: typed methods for every backend endpoint
    │   │
    │   └── screens/                    ← One folder per screen
    │       ├── shell_screen.dart       ← App shell: sidebar nav + avatar dropdown (Profile/Settings)
    │       ├── overview/
    │       │   └── overview_screen.dart   ← Dashboard: stats bento, vitals, chart, recent archives
    │       ├── vault/
    │       │   └── vault_screen.dart      ← Folder chips, file grid/list, preview, AI summary panel
    │       ├── chat/
    │       │   └── chat_screen.dart       ← Chat bubbles, typing indicator, vault picker sheet
    │       ├── notebook/
    │       │   └── notebook_screen.dart   ← Text editor, formatting toolbar, AI insights sidebar
    │       ├── profile/
    │       │   └── profile_screen.dart    ← Patient header, clinical composition, insurance card
    │       └── settings/
    │           └── settings_screen.dart   ← Account form, theme toggle, notifications, security
    │
    ├── web/                            ← Web platform files (auto-generated)
    │   ├── index.html
    │   ├── manifest.json
    │   └── icons/
    │
    └── windows/                        ← Windows desktop platform files (auto-generated)
        ├── CMakeLists.txt
        ├── flutter/
        └── runner/
```

---

## Layer Responsibilities

| Layer | Technology | Responsibility |
|---|---|---|
| **Agents** | Agno v2 `Team` + `Agent` | Multi-agent orchestration (supervisor + clinical analyst + radiologist) |
| **API** | FastAPI routers | HTTP interface — request validation, DI, response shaping |
| **Models** | Pydantic v2 | Schema contracts between API ↔ clients and API ↔ DB |
| **DB** | SQLite + LanceDB | Structured metadata (SQLite) + semantic vector search (LanceDB/GeminiEmbedder) |
| **Services** | Pure Python | PDF parsing, image preprocessing — no HTTP concerns |
| **Core** | Pydantic Settings | Config injection, custom exceptions |
| **Flutter** | Dart + Material 3 | Full UI: design system, API client, 7 screens |

---

## Data Flow

```
User (Flutter UI)
    │  HTTP (JSON / multipart)
    ▼
FastAPI  ─── api/routes_*.py
    │
    ├── SQLite (metadata, notes, profile, chat history)
    │       db/sqlite_db.py
    │
    ├── LanceDB (vector embeddings for RAG)
    │       db/vector_store.py
    │
    └── Agno Team (AI inference)
            agents/routing_agent.py
                ├── Clinical Analyst  ─── LanceDB knowledge base
                └── Radiologist       ─── Vision (image bytes)
```

---

## Run Commands

```bash
# ── Backend ────────────────────────────────────────────────
cd Backend_1
uv run uvicorn main:app --reload
# API docs → http://localhost:8000/docs

# ── Flutter (Windows desktop) ──────────────────────────────
cd Backend_1/med_rag_flutter
flutter pub get
flutter run -d windows

# ── Flutter (Chrome / web) ─────────────────────────────────
flutter run -d chrome
```
