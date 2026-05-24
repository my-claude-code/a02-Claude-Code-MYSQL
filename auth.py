from functools import wraps

import msal
from flask import (
    Blueprint,
    current_app,
    redirect,
    render_template,
    request,
    session,
    url_for,
)

auth_bp = Blueprint("auth", __name__)


def login_required(f):
    """Redirect unauthenticated requests to the login page."""
    @wraps(f)
    def decorated(*args, **kwargs):
        if "user" not in session:
            return redirect(url_for("auth.login"))
        return f(*args, **kwargs)
    return decorated


def _build_msal_app() -> msal.ConfidentialClientApplication:
    return msal.ConfidentialClientApplication(
        current_app.config["ENTRA_CLIENT_ID"],
        authority=current_app.config["AUTHORITY"],
        client_credential=current_app.config["ENTRA_CLIENT_SECRET"],
    )


@auth_bp.route("/login")
def login():
    if "user" in session:
        return redirect(url_for("dashboard"))

    msal_app = _build_msal_app()
    # initiate_auth_code_flow generates the auth URL and a PKCE verifier/state
    # that must survive until the callback — stored in the server-side session.
    flow = msal_app.initiate_auth_code_flow(
        scopes=current_app.config["SCOPES"],
        redirect_uri=current_app.config["REDIRECT_URI"],
    )
    session["auth_flow"] = flow
    return redirect(flow["auth_uri"])


@auth_bp.route("/auth/callback")
def callback():
    if "auth_flow" not in session:
        return redirect(url_for("auth.login"))

    msal_app = _build_msal_app()
    result = msal_app.acquire_token_by_auth_code_flow(
        session.pop("auth_flow"),
        request.args,
    )

    if "error" in result:
        error_desc = result.get("error_description") or result["error"]
        return render_template("login.html", error=error_desc), 400

    claims = result.get("id_token_claims", {})
    # Prefer the stable, non-recyclable OID; fall back to the UPN (preferred_username).
    user_id = claims.get("oid") or claims.get("preferred_username", "")

    session["user"] = {
        "id": user_id,
        "name": claims.get("name", ""),
        "email": claims.get("preferred_username", ""),
    }
    # Access token is intentionally not stored — only the identity claims are kept.
    return redirect(url_for("dashboard"))


@auth_bp.route("/logout")
def logout():
    session.clear()
    # Sign the user out on the Microsoft side as well, then return to the login page.
    post_logout = url_for("auth.login", _external=True)
    logout_url = (
        f"{current_app.config['AUTHORITY']}/oauth2/v2.0/logout"
        f"?post_logout_redirect_uri={post_logout}"
    )
    return redirect(logout_url)
