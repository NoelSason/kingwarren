from __future__ import annotations

import os
from contextlib import contextmanager
from pathlib import Path
from typing import Any

from databricks import sql as dbsql
from dotenv import load_dotenv
from supabase import Client, create_client

BASE_DIR = Path(__file__).resolve().parent.parent
for _p in (BASE_DIR / ".env", BASE_DIR / ".gitignore" / ".env"):
    if _p.exists():
        load_dotenv(_p, override=False)

SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_ANON_KEY = (
    os.getenv("SUPABASE_ANON_KEY")
    or os.getenv("SUPABASE_KEY")
    or os.getenv("NEXT_PUBLIC_SUPABASE_ANON_KEY")
    or ""
)
FLASK_SECRET_KEY = os.getenv("FLASK_SECRET_KEY", "dev-secret-key")

DATABRICKS_HOST = os.getenv("DATABRICKS_HOST", "")
DATABRICKS_HTTP_PATH = os.getenv("DATABRICKS_HTTP_PATH", "")
DATABRICKS_TOKEN = os.getenv("DATABRICKS_TOKEN", "")


# ---------------------------------------------------------------------------
# Config checks
# ---------------------------------------------------------------------------

def get_config_error() -> str | None:
    missing = []
    if not SUPABASE_URL:
        missing.append("SUPABASE_URL")
    if not SUPABASE_ANON_KEY:
        missing.append("SUPABASE_ANON_KEY")
    if not missing:
        return None
    return (
        f"Missing {' and '.join(missing)}. Add them to `.env`, `.gitignore/.env`, "
        "or directly in `backend/db.py`, then restart the Flask server."
    )


def is_supabase_configured() -> bool:
    return get_config_error() is None


def is_databricks_configured() -> bool:
    return bool(DATABRICKS_HOST and DATABRICKS_HTTP_PATH and DATABRICKS_TOKEN)


# ---------------------------------------------------------------------------
# Supabase (auth only)
# ---------------------------------------------------------------------------

def get_supabase_client() -> Client:
    err = get_config_error()
    if err:
        raise RuntimeError(err)
    return create_client(SUPABASE_URL, SUPABASE_ANON_KEY)


def create_account(*, email: str, password: str, username: str, display_name: str):
    client = get_supabase_client()
    return client.auth.sign_up({
        "email": email,
        "password": password,
        "options": {"data": {"username": username, "display_name": display_name}},
    })


def sign_in(*, email: str, password: str):
    client = get_supabase_client()
    return client.auth.sign_in_with_password({"email": email, "password": password})


# ---------------------------------------------------------------------------
# Databricks
# ---------------------------------------------------------------------------

@contextmanager
def _databricks_conn():
    conn = dbsql.connect(
        server_hostname=DATABRICKS_HOST,
        http_path=DATABRICKS_HTTP_PATH,
        access_token=DATABRICKS_TOKEN,
    )
    try:
        yield conn
    finally:
        conn.close()


def databricks_setup_tables() -> None:
    """Create the oceanscore catalog tables if they don't exist."""
    with _databricks_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS workspace.default.profiles (
                    id STRING NOT NULL,
                    display_name STRING NOT NULL,
                    username STRING NOT NULL,
                    email STRING NOT NULL,
                    seabucks INT NOT NULL,
                    created_at TIMESTAMP
                )
                USING DELTA
            """)


def upsert_profile(
    *,
    user_id: str,
    email: str,
    username: str,
    display_name: str,
    seabucks: int = 0,
) -> None:
    with _databricks_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                MERGE INTO workspace.default.profiles AS target
                USING (SELECT
                    %(id)s AS id,
                    %(display_name)s AS display_name,
                    %(username)s AS username,
                    %(email)s AS email,
                    %(seabucks)s AS seabucks
                ) AS source
                ON target.id = source.id
                WHEN MATCHED THEN UPDATE SET
                    display_name = source.display_name,
                    username = source.username,
                    email = source.email
                WHEN NOT MATCHED THEN INSERT
                    (id, display_name, username, email, seabucks, created_at)
                VALUES
                    (source.id, source.display_name, source.username, source.email, source.seabucks, current_timestamp())
            """, {
                "id": user_id,
                "display_name": display_name,
                "username": username,
                "email": email,
                "seabucks": seabucks,
            })


def get_profile_from_databricks(user_id: str) -> dict[str, Any] | None:
    with _databricks_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, display_name, username, email, seabucks, created_at "
                "FROM workspace.default.profiles WHERE id = %(id)s LIMIT 1",
                {"id": user_id},
            )
            row = cur.fetchone()
            if not row:
                return None
            cols = [d[0] for d in cur.description]
            data = dict(zip(cols, row))
            if hasattr(data.get("created_at"), "isoformat"):
                data["created_at"] = data["created_at"].isoformat()
            return data


def check_duplicate(*, email: str, username: str) -> list[str]:
    if not is_databricks_configured():
        return []
    try:
        with _databricks_conn() as conn:
            with conn.cursor() as cur:
                errors = []
                cur.execute(
                    "SELECT id FROM workspace.default.profiles WHERE email = %(email)s LIMIT 1",
                    {"email": email},
                )
                if cur.fetchone():
                    errors.append("An account with that email already exists.")
                cur.execute(
                    "SELECT id FROM workspace.default.profiles WHERE username = %(username)s LIMIT 1",
                    {"username": username},
                )
                if cur.fetchone():
                    errors.append("That username is already taken.")
                return errors
    except Exception:
        return []


# ---------------------------------------------------------------------------
# Profile snapshot (used by /app route)
# ---------------------------------------------------------------------------

def get_profile_snapshot(access_token: str, refresh_token: str) -> dict[str, Any]:
    client = get_supabase_client()
    client.auth.set_session(access_token, refresh_token)
    user_response = client.auth.get_user()
    user = getattr(user_response, "user", None)
    if not user:
        raise RuntimeError("No authenticated user found for the current session.")

    profile = None
    if is_databricks_configured():
        try:
            profile = get_profile_from_databricks(user.id)
        except Exception:
            pass

    return {
        "auth_user": {
            "id": user.id,
            "email": user.email,
            "user_metadata": user.user_metadata,
        },
        "profile": profile,
        "source": "databricks" if profile else "supabase_auth_only",
    }
