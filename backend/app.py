from __future__ import annotations

import json
import re

from flask import Flask, flash, redirect, render_template, request, session, url_for

from db import (
    FLASK_SECRET_KEY,
    check_duplicate,
    create_account,
    get_config_error,
    get_profile_snapshot,
    is_supabase_configured,
    sign_in,
)

app = Flask(__name__)
app.secret_key = FLASK_SECRET_KEY

EMAIL_PATTERN = re.compile(r"[^@\s]+@[^@\s]+\.[^@\s]+")
USERNAME_PATTERN = re.compile(r"[a-z0-9_]{3,24}")


def normalize_email(email: str) -> str:
    return email.strip().lower()


def validate_signup_form(form: dict[str, str]) -> list[str]:
    errors: list[str] = []
    display_name = form.get("display_name", "").strip()
    username = form.get("username", "").strip().lower()
    email = normalize_email(form.get("email", ""))
    password = form.get("password", "")
    confirm_password = form.get("confirm_password", "")

    if not display_name:
        errors.append("Display name is required.")
    if not USERNAME_PATTERN.fullmatch(username):
        errors.append("Username must be 3-24 characters and use only letters, numbers, or underscores.")
    if not EMAIL_PATTERN.fullmatch(email):
        errors.append("Enter a valid email address.")
    if len(password) < 8:
        errors.append("Password must be at least 8 characters.")
    if password != confirm_password:
        errors.append("Passwords do not match.")

    return errors


def store_auth_session(auth_response) -> None:
    auth_session = getattr(auth_response, "session", None)
    if auth_session:
        session["access_token"] = auth_session.access_token
        session["refresh_token"] = auth_session.refresh_token


def store_profile_preview(*, email: str, username: str, display_name: str, user_id: str | None) -> None:
    session["profile_preview"] = {
        "auth_user": {
            "id": user_id,
            "email": email,
            "user_metadata": {
                "username": username,
                "display_name": display_name,
            },
        },
        "profile": {
            "id": user_id,
            "display_name": display_name,
            "username": username,
            "email": email,
            "seabucks": 0,
        },
    }


@app.get("/")
def landing():
    return render_template(
        "auth.html",
        mode=request.args.get("mode", "signup"),
        configured=is_supabase_configured(),
        config_error=get_config_error(),
    )


@app.post("/signup")
def signup_route():
    form = {key: value for key, value in request.form.items()}

    if not is_supabase_configured():
        flash(get_config_error(), "error")
        return render_template(
            "auth.html",
            mode="signup",
            form=form,
            configured=False,
            config_error=get_config_error(),
        ), 400

    errors = validate_signup_form(form)

    if not errors:
        try:
            dup_errors = check_duplicate(
                email=normalize_email(form["email"]),
                username=form["username"].strip().lower(),
            )
            errors.extend(dup_errors)
        except Exception as exc:
            flash(str(exc), "error")
            return render_template("auth.html", mode="signup", form=form, configured=True, config_error=None), 400

    if errors:
        for error in errors:
            flash(error, "error")
        return render_template(
            "auth.html",
            mode="signup",
            form=form,
            configured=True,
            config_error=None,
        ), 400

    try:
        response = create_account(
            email=normalize_email(form["email"]),
            password=form["password"],
            username=form["username"].strip().lower(),
            display_name=form["display_name"].strip(),
        )
    except Exception as exc:  # pragma: no cover - depends on live Supabase response
        flash(str(exc), "error")
        return render_template(
            "auth.html",
            mode="signup",
            form=form,
            configured=True,
            config_error=None,
        ), 400

    user = getattr(response, "user", None)
    session["user_email"] = normalize_email(form["email"])
    session["user_id"] = getattr(user, "id", None)
    session["test_password"] = form["password"]
    store_auth_session(response)
    store_profile_preview(
        email=normalize_email(form["email"]),
        username=form["username"].strip().lower(),
        display_name=form["display_name"].strip(),
        user_id=getattr(user, "id", None),
    )
    return redirect(url_for("blank_page"))


@app.post("/signin")
def signin_route():
    email = normalize_email(request.form.get("email", ""))
    password = request.form.get("password", "")

    if not is_supabase_configured():
        flash(get_config_error(), "error")
        return render_template(
            "auth.html",
            mode="signin",
            form={"email": email},
            configured=False,
            config_error=get_config_error(),
        ), 400

    if not EMAIL_PATTERN.fullmatch(email):
        flash("Enter a valid email address.", "error")
        return render_template(
            "auth.html",
            mode="signin",
            form={"email": email},
            configured=True,
            config_error=None,
        ), 400

    if not password:
        flash("Password is required.", "error")
        return render_template(
            "auth.html",
            mode="signin",
            form={"email": email},
            configured=True,
            config_error=None,
        ), 400

    try:
        response = sign_in(email=email, password=password)
    except Exception as exc:  # pragma: no cover - depends on live Supabase response
        flash(str(exc), "error")
        return render_template(
            "auth.html",
            mode="signin",
            form={"email": email},
            configured=True,
            config_error=None,
        ), 400

    user = getattr(response, "user", None)
    session["user_email"] = email
    session["user_id"] = getattr(user, "id", None)
    store_auth_session(response)
    session.pop("profile_preview", None)
    return redirect(url_for("blank_page"))


@app.get("/app")
def blank_page():
    if "user_email" not in session:
        return redirect(url_for("landing"))

    snapshot = None
    fetch_error = None

    access_token = session.get("access_token")
    refresh_token = session.get("refresh_token")

    if access_token and refresh_token:
        try:
            snapshot = get_profile_snapshot(access_token, refresh_token)
        except Exception as exc:  # pragma: no cover - depends on live Supabase response
            fetch_error = str(exc)

    if snapshot is None:
        snapshot = session.get("profile_preview")

    if snapshot is None:
        snapshot = {
            "auth_user": {
                "id": session.get("user_id"),
                "email": session.get("user_email"),
            },
            "profile": None,
        }

    pretty_snapshot = json.dumps(snapshot, indent=2, sort_keys=True)
    test_password = session.pop("test_password", None)
    return render_template("blank.html", snapshot=snapshot, pretty_snapshot=pretty_snapshot, fetch_error=fetch_error, test_password=test_password)


@app.post("/signout")
def signout_route():
    session.clear()
    return redirect(url_for("landing"))


if __name__ == "__main__":
    app.run(debug=True)
