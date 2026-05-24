# Flask Entra Notes

A Flask web application with Microsoft Entra ID (Azure AD) authentication and a per-user notes CRUD system.

## Prerequisites

- Python 3.12 or later
- A Microsoft Entra ID tenant
- An App Registration in that tenant (see step 5 below)

---

## 1. Clone or download the project

```bash
git clone <your-repo-url>
cd flask-entra-notes
```

---

## 2. Create a virtual environment

```bash
python -m venv venv

# Linux / macOS
source venv/bin/activate

# Windows
venv\Scripts\activate
```

---

## 3. Install dependencies

```bash
pip install -r requirements.txt
```

---

## 4. Configure environment variables

```bash
cp .env.example .env
```

Open `.env` and fill in the four required values:

| Variable | Where to find it |
|---|---|
| `ENTRA_CLIENT_ID` | Application (client) ID in your App Registration overview |
| `ENTRA_CLIENT_SECRET` | Client secret value created under Certificates & secrets |
| `ENTRA_TENANT_ID` | Directory (tenant) ID in your App Registration overview |
| `FLASK_SECRET_KEY` | A long random string you generate yourself |

Generate a strong secret key:

```bash
python -c "import secrets; print(secrets.token_hex(32))"
```

---

## 5. Microsoft Entra App Registration

In the [Azure Portal](https://portal.azure.com):

1. Go to **Microsoft Entra ID → App registrations → New registration**
2. **Name**: e.g. `flask-entra-notes`
3. **Supported account types**: *Accounts in this organizational directory only (Single tenant)*
4. **Redirect URI**: choose **Web** platform → enter `http://localhost:5000/auth/callback`
5. Click **Register**
6. From the **Overview** page, copy:
   - **Application (client) ID** → paste as `ENTRA_CLIENT_ID` in `.env`
   - **Directory (tenant) ID** → paste as `ENTRA_TENANT_ID` in `.env`
7. Go to **Certificates & secrets → New client secret**, choose an expiry, click **Add**
8. Copy the **Value** immediately (shown only once) → paste as `ENTRA_CLIENT_SECRET` in `.env`
9. Go to **API permissions** — the default delegated permissions (`openid`, `profile`, `email`) are sufficient. No additional grants are needed.

---

## 6. Initialize the database

```bash
flask init-db
```

This creates `app.db` (SQLite) in the project directory.

---

## 7. Run the application

```bash
flask run
```

Open [http://localhost:5000](http://localhost:5000) in your browser and click **Sign in with Microsoft**.

---

## Switching from SQLite to MySQL

1. Install the MySQL driver:
   ```bash
   pip install pymysql
   ```
2. In your `.env`, replace the `DATABASE_URL` line:
   ```
   DATABASE_URL=mysql+pymysql://<mysql_user>:<mysql_password>@<mysql_host>:3306/<mysql_database>
   ```
3. Re-run `flask init-db` to create the tables in MySQL.

---

## Project structure

```
flask-entra-notes/
  app.py            — Flask app factory, all notes routes (CRUD)
  auth.py           — Auth blueprint: /login, /auth/callback, /logout + login_required
  config.py         — Config class that loads from .env
  models.py         — SQLAlchemy Note model (id, owner_id, title, body, timestamps)
  requirements.txt  — Python dependencies
  .env.example      — Environment variable template
  .gitignore
  README.md
  templates/
    base.html       — Bootstrap 5 layout, navbar, flash messages
    login.html      — Sign-in landing page
    dashboard.html  — Note listing with edit / delete per note
    note_form.html  — Create / edit form
```

---

## Security notes

- **Session isolation**: all note queries filter by `owner_id` (the user's OID from Entra ID). A note belonging to another user returns HTTP 404, not a permission error — no information is leaked.
- **CSRF**: Flask-WTF's `CSRFProtect` validates a token on every state-changing form POST.
- **Access tokens**: not persisted. Only the user's identity claims (OID, name, email) are stored in the server-side session.
- **Production checklist**:
  - Set `SESSION_COOKIE_SECURE = True` in `config.py` once the app is behind HTTPS
  - Use a randomly generated `FLASK_SECRET_KEY` stored in a secrets vault
  - Rotate the Entra client secret before it expires
  - Consider switching `SESSION_TYPE` to `sqlalchemy` or `redis` for multi-process deployments
