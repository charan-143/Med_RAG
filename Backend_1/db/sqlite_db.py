"""
SQLite database layer for Clinical Atelier.
Manages: file metadata, folders, notebook notes, chat history, patient profile.
Uses the stdlib `sqlite3` — zero extra dependencies required.
"""

import sqlite3
import os
import uuid
from datetime import datetime
from pathlib import Path

DB_PATH = os.path.join("data", "clinical_atelier.db")

def get_conn() -> sqlite3.Connection:
    os.makedirs("data", exist_ok=True)
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL;")
    return conn


def init_db():
    """Create all tables if they don't exist."""
    with get_conn() as conn:
        conn.executescript("""
            CREATE TABLE IF NOT EXISTS folders (
                id          TEXT PRIMARY KEY,
                name        TEXT NOT NULL UNIQUE,
                icon        TEXT DEFAULT 'folder',
                created_at  TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS files (
                id              TEXT PRIMARY KEY,
                original_name   TEXT NOT NULL,
                safe_name       TEXT NOT NULL,
                file_type       TEXT NOT NULL,
                mime_type       TEXT,
                size_bytes      INTEGER DEFAULT 0,
                folder_id       TEXT,
                ai_name         TEXT,
                ai_summary      TEXT,
                uploaded_at     TEXT NOT NULL,
                FOREIGN KEY(folder_id) REFERENCES folders(id)
            );

            CREATE TABLE IF NOT EXISTS notes (
                id          TEXT PRIMARY KEY,
                title       TEXT NOT NULL DEFAULT 'Untitled Entry',
                content     TEXT NOT NULL DEFAULT '',
                tags        TEXT DEFAULT '',
                is_pinned   INTEGER DEFAULT 0,
                source      TEXT DEFAULT 'manual',
                source_ref  TEXT,
                created_at  TEXT NOT NULL,
                updated_at  TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS chat_history (
                id          TEXT PRIMARY KEY,
                role        TEXT NOT NULL,
                content     TEXT NOT NULL,
                context_ids TEXT DEFAULT '',
                created_at  TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS profile (
                id              TEXT PRIMARY KEY DEFAULT 'default',
                full_name       TEXT DEFAULT 'Patient',
                dob             TEXT,
                gender          TEXT,
                blood_type      TEXT,
                phone           TEXT,
                email           TEXT,
                address         TEXT,
                emergency_name  TEXT,
                emergency_phone TEXT,
                emergency_rel   TEXT,
                allergies       TEXT DEFAULT '',
                conditions      TEXT DEFAULT '',
                medications     TEXT DEFAULT '',
                insurance_provider TEXT,
                insurance_policy   TEXT,
                updated_at      TEXT NOT NULL
            );
        """)

        # Seed default folders if none exist
        cur = conn.execute("SELECT COUNT(*) FROM folders")
        if cur.fetchone()[0] == 0:
            now = datetime.utcnow().isoformat()
            default_folders = [
                (str(uuid.uuid4()), "Prescriptions", "prescriptions", now),
                (str(uuid.uuid4()), "X-Rays",        "radiology",     now),
                (str(uuid.uuid4()), "Lab Reports",   "biotech",       now),
                (str(uuid.uuid4()), "Imaging",       "photo_camera",  now),
            ]
            conn.executemany(
                "INSERT INTO folders(id, name, icon, created_at) VALUES (?,?,?,?)",
                default_folders
            )

        # Seed default profile if none exists
        cur = conn.execute("SELECT COUNT(*) FROM profile")
        if cur.fetchone()[0] == 0:
            now = datetime.utcnow().isoformat()
            conn.execute("""
                INSERT INTO profile(id, full_name, dob, gender, blood_type,
                    phone, email, insurance_provider, updated_at)
                VALUES ('default','Julian Thorne','1985-05-24','Male','A+',
                    '+1 (555) 012-3344','j.thorne@atelier.care','BlueShield Premium Elite',?)
            """, (now,))
        conn.commit()


# ─── Folder helpers ────────────────────────────────────────────────────────────
def list_folders():
    with get_conn() as conn:
        rows = conn.execute("SELECT * FROM folders ORDER BY name").fetchall()
        return [dict(r) for r in rows]

def create_folder(name: str, icon: str = "folder") -> dict:
    with get_conn() as conn:
        fid = str(uuid.uuid4())
        now = datetime.utcnow().isoformat()
        conn.execute("INSERT INTO folders(id,name,icon,created_at) VALUES(?,?,?,?)",
                     (fid, name, icon, now))
        conn.commit()
        return {"id": fid, "name": name, "icon": icon, "created_at": now}

def delete_folder(folder_id: str):
    with get_conn() as conn:
        conn.execute("DELETE FROM folders WHERE id=?", (folder_id,))
        conn.commit()

def get_folder_file_count(folder_id: str) -> int:
    with get_conn() as conn:
        r = conn.execute("SELECT COUNT(*) FROM files WHERE folder_id=?", (folder_id,)).fetchone()
        return r[0] if r else 0


# ─── File helpers ───────────────────────────────────────────────────────────────
def insert_file(original_name: str, safe_name: str, file_type: str,
                mime_type: str = None, size_bytes: int = 0,
                folder_id: str = None, ai_name: str = None) -> dict:
    with get_conn() as conn:
        fid = str(uuid.uuid4())
        now = datetime.utcnow().isoformat()
        conn.execute("""
            INSERT INTO files(id,original_name,safe_name,file_type,mime_type,
                size_bytes,folder_id,ai_name,uploaded_at)
            VALUES(?,?,?,?,?,?,?,?,?)
        """, (fid, original_name, safe_name, file_type, mime_type,
              size_bytes, folder_id, ai_name or original_name, now))
        conn.commit()
        return get_file(fid)

def get_file(file_id: str) -> dict | None:
    with get_conn() as conn:
        r = conn.execute("SELECT * FROM files WHERE id=?", (file_id,)).fetchone()
        return dict(r) if r else None

def list_files(folder_id: str = None) -> list:
    with get_conn() as conn:
        if folder_id:
            rows = conn.execute(
                "SELECT * FROM files WHERE folder_id=? ORDER BY uploaded_at DESC", (folder_id,)
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT * FROM files ORDER BY uploaded_at DESC"
            ).fetchall()
        return [dict(r) for r in rows]

def update_file_ai(file_id: str, ai_name: str = None, ai_summary: str = None):
    with get_conn() as conn:
        if ai_name:
            conn.execute("UPDATE files SET ai_name=? WHERE id=?", (ai_name, file_id))
        if ai_summary:
            conn.execute("UPDATE files SET ai_summary=? WHERE id=?", (ai_summary, file_id))
        conn.commit()

def delete_file_record(file_id: str) -> str | None:
    """Returns safe filename for disk deletion."""
    with get_conn() as conn:
        r = conn.execute("SELECT safe_name FROM files WHERE id=?", (file_id,)).fetchone()
        if r:
            conn.execute("DELETE FROM files WHERE id=?", (file_id,))
            conn.commit()
            return r["safe_name"]
    return None

def get_overview_stats() -> dict:
    with get_conn() as conn:
        total = conn.execute("SELECT COUNT(*) FROM files").fetchone()[0]
        by_type = conn.execute(
            "SELECT file_type, COUNT(*) as cnt FROM files GROUP BY file_type"
        ).fetchall()
        recent = conn.execute(
            "SELECT * FROM files ORDER BY uploaded_at DESC LIMIT 5"
        ).fetchall()
        folders = conn.execute("SELECT COUNT(*) FROM folders").fetchone()[0]
        return {
            "total_records": total,
            "total_folders": folders,
            "by_type": {r["file_type"]: r["cnt"] for r in by_type},
            "recent_files": [dict(r) for r in recent],
        }


# ─── Note helpers ───────────────────────────────────────────────────────────────
def list_notes() -> list:
    with get_conn() as conn:
        rows = conn.execute(
            "SELECT * FROM notes ORDER BY is_pinned DESC, updated_at DESC"
        ).fetchall()
        return [dict(r) for r in rows]

def get_note(note_id: str) -> dict | None:
    with get_conn() as conn:
        r = conn.execute("SELECT * FROM notes WHERE id=?", (note_id,)).fetchone()
        return dict(r) if r else None

def create_note(title: str, content: str = "", tags: str = "",
                source: str = "manual", source_ref: str = None) -> dict:
    with get_conn() as conn:
        nid = str(uuid.uuid4())
        now = datetime.utcnow().isoformat()
        conn.execute("""
            INSERT INTO notes(id,title,content,tags,source,source_ref,created_at,updated_at)
            VALUES(?,?,?,?,?,?,?,?)
        """, (nid, title, content, tags, source, source_ref, now, now))
        conn.commit()
        return get_note(nid)

def update_note(note_id: str, title: str = None, content: str = None,
                tags: str = None, is_pinned: bool = None) -> dict | None:
    with get_conn() as conn:
        note = get_note(note_id)
        if not note:
            return None
        now = datetime.utcnow().isoformat()
        updates = {"updated_at": now}
        if title is not None:    updates["title"] = title
        if content is not None:  updates["content"] = content
        if tags is not None:     updates["tags"] = tags
        if is_pinned is not None: updates["is_pinned"] = int(is_pinned)
        set_clause = ", ".join(f"{k}=?" for k in updates)
        vals = list(updates.values()) + [note_id]
        conn.execute(f"UPDATE notes SET {set_clause} WHERE id=?", vals)
        conn.commit()
        return get_note(note_id)

def delete_note(note_id: str) -> bool:
    with get_conn() as conn:
        conn.execute("DELETE FROM notes WHERE id=?", (note_id,))
        conn.commit()
        return True


# ─── Chat history helpers ───────────────────────────────────────────────────────
def save_chat_message(role: str, content: str, context_ids: str = "") -> dict:
    with get_conn() as conn:
        mid = str(uuid.uuid4())
        now = datetime.utcnow().isoformat()
        conn.execute(
            "INSERT INTO chat_history(id,role,content,context_ids,created_at) VALUES(?,?,?,?,?)",
            (mid, role, content, context_ids, now)
        )
        conn.commit()
        return {"id": mid, "role": role, "content": content,
                "context_ids": context_ids, "created_at": now}

def list_chat_history(limit: int = 50) -> list:
    with get_conn() as conn:
        rows = conn.execute(
            "SELECT * FROM chat_history ORDER BY created_at DESC LIMIT ?", (limit,)
        ).fetchall()
        return list(reversed([dict(r) for r in rows]))


# ─── Profile helpers ────────────────────────────────────────────────────────────
def get_profile() -> dict | None:
    with get_conn() as conn:
        r = conn.execute("SELECT * FROM profile WHERE id='default'").fetchone()
        return dict(r) if r else None

def update_profile(**kwargs) -> dict:
    with get_conn() as conn:
        now = datetime.utcnow().isoformat()
        kwargs["updated_at"] = now
        set_clause = ", ".join(f"{k}=?" for k in kwargs)
        vals = list(kwargs.values())
        conn.execute(f"UPDATE profile SET {set_clause} WHERE id='default'", vals)
        conn.commit()
        return get_profile()
