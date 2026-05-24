import os

from dotenv import load_dotenv

load_dotenv()


class Config:
    # Flask core
    SECRET_KEY = os.environ.get("FLASK_SECRET_KEY") or "change-me-in-production"

    # Microsoft Entra ID (Azure AD) — OAuth2 / OpenID Connect
    ENTRA_CLIENT_ID = os.environ.get("ENTRA_CLIENT_ID")
    ENTRA_CLIENT_SECRET = os.environ.get("ENTRA_CLIENT_SECRET")
    ENTRA_TENANT_ID = os.environ.get("ENTRA_TENANT_ID")
    REDIRECT_URI = os.environ.get("REDIRECT_URI", "http://localhost:5000/auth/callback")
    AUTHORITY = (
        "https://login.microsoftonline.com/"
        + os.environ.get("ENTRA_TENANT_ID", "common")
    )
    # Minimal OpenID Connect scopes — no elevated API permissions required
    SCOPES = []

    # Database — SQLite by default; swap DATABASE_URL in .env for MySQL (see .env.example)
    SQLALCHEMY_DATABASE_URI = os.environ.get("DATABASE_URL", "sqlite:///app.db")
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    # Server-side session via Flask-Session (filesystem-backed).
    # Avoids cookie-size limits caused by storing the MSAL auth_flow dict in the browser.
    SESSION_TYPE = "filesystem"
    SESSION_FILE_DIR = "flask_session"
    SESSION_PERMANENT = False

    # Session cookie hardening
    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SAMESITE = "Lax"
    # Set SESSION_COOKIE_SECURE = True in production when served over HTTPS
    SESSION_COOKIE_SECURE = False
