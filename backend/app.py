from __future__ import annotations

import threading
from flask import Flask, jsonify, request
from db import (
    FLASK_SECRET_KEY,
    create_account,
    get_config_error,
    get_profile_from_databricks,
    get_supabase_client,
    is_databricks_configured,
    is_supabase_configured,
    sign_in,
    upsert_profile,
)

app = Flask(__name__)
app.secret_key = FLASK_SECRET_KEY


def _err(msg: str, status: int = 400):
    return jsonify({"error": msg}), status


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------

@app.get("/api/health")
def health():
    return jsonify({
        "supabase": is_supabase_configured(),
        "databricks": is_databricks_configured(),
    })


# ---------------------------------------------------------------------------
# Profile
# ---------------------------------------------------------------------------

@app.post("/api/profile")
def api_profile_upsert():
    data = request.get_json(silent=True) or {}
    user_id = data.get("user_id", "").strip()
    email = data.get("email", "").strip().lower()
    username = data.get("username", "").strip().lower()
    display_name = data.get("display_name", "").strip()

    if not all([user_id, email, username, display_name]):
        return _err("user_id, email, username, and display_name are required.")

    if not is_databricks_configured():
        return _err("Databricks is not configured.", 503)

    def _write():
        try:
            upsert_profile(
                user_id=user_id,
                email=email,
                username=username,
                display_name=display_name,
                seabucks=0,
            )
        except Exception:
            pass

    threading.Thread(target=_write, daemon=True).start()
    return jsonify({"ok": True})


@app.get("/api/profile/<user_id>")
def api_profile_get(user_id: str):
    if not is_databricks_configured():
        return _err("Databricks is not configured.", 503)
    try:
        profile = get_profile_from_databricks(user_id)
        if not profile:
            return _err("Profile not found.", 404)
        return jsonify(profile)
    except Exception as exc:
        return _err(str(exc), 500)


# ---------------------------------------------------------------------------
# Ocean stress
# ---------------------------------------------------------------------------

@app.get("/api/ocean-stress")
def api_ocean_stress():
    # TODO: replace with live CalCOFI / CCE pipeline data
    return jsonify({
        "stress_index": 1.34,
        "location": "CCE2 mooring · San Diego shelf",
        "updated_at": "2026-04-18T10:00:00Z",
    })


if __name__ == "__main__":
    app.run(debug=True)
