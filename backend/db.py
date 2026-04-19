from __future__ import annotations

import os
from pathlib import Path
from typing import Any

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


def get_supabase_client() -> Client:
    err = get_config_error()
    if err:
        raise RuntimeError(err)
    return create_client(SUPABASE_URL, SUPABASE_ANON_KEY)


def check_duplicate(*, email: str, username: str) -> list[str]:
    try:
        client = get_supabase_client()
        errors = []
        email_check = client.table("profiles").select("id").eq("email", email).execute()
        if email_check.data:
            errors.append("An account with that email already exists.")
        username_check = client.table("profiles").select("id").eq("username", username).execute()
        if username_check.data:
            errors.append("That username is already taken.")
        return errors
    except Exception:
        # profiles table not set up yet — skip duplicate check, let Supabase auth handle it
        return []


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


def get_profile_snapshot(access_token: str, refresh_token: str) -> dict[str, Any]:
    client = get_supabase_client()
    client.auth.set_session(access_token, refresh_token)
    user_response = client.auth.get_user()
    user = getattr(user_response, "user", None)
    if not user:
        raise RuntimeError("No authenticated user found for the current session.")
    profile_response = (
        client.table("profiles").select("*").eq("id", user.id).maybe_single().execute()
    )
    return {
        "auth_user": {
            "id": user.id,
            "email": user.email,
            "user_metadata": user.user_metadata,
        },
        "profile": profile_response.data,
    }
