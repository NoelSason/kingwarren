from __future__ import annotations

import re
from getpass import getpass

from db import create_account


def prompt_non_empty(label: str) -> str:
    while True:
        value = input(f"{label}: ").strip()
        if value:
            return value
        print(f"{label} is required.")


def prompt_email() -> str:
    while True:
        email = input("Email: ").strip().lower()
        if re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email):
            return email
        print("Enter a valid email address.")


def prompt_username() -> str:
    while True:
        username = input("Username: ").strip().lower()
        if re.fullmatch(r"[a-z0-9_]{3,24}", username):
            return username
        print("Username must be 3-24 characters and use only letters, numbers, or underscores.")


def prompt_password() -> str:
    while True:
        password = getpass("Password: ")
        confirm_password = getpass("Confirm password: ")

        if len(password) < 8:
            print("Password must be at least 8 characters.")
            continue

        if password != confirm_password:
            print("Passwords do not match.")
            continue

        return password


def main() -> None:
    print("Create your OceanScore account")
    print("Fill out every field below.\n")

    display_name = prompt_non_empty("Display name")
    username = prompt_username()
    email = prompt_email()
    password = prompt_password()

    response = create_account(
        email=email,
        password=password,
        username=username,
        display_name=display_name,
    )

    user = getattr(response, "user", None)
    session = getattr(response, "session", None)

    print("\nAccount created.")
    print("Starting seabucks: 0")

    if user and not getattr(user, "email_confirmed_at", None):
        print("Check your email to confirm the account if email confirmation is enabled in Supabase.")
    elif session:
        print("Signup completed and the user session is active.")


if __name__ == "__main__":
    main()
