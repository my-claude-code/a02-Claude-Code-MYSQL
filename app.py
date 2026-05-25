from flask import Flask, flash, redirect, render_template, request, session, url_for
from flask_session import Session
from flask_wtf.csrf import CSRFProtect

from auth import auth_bp, login_required
from config import Config
from models import Note, db


def create_app(config_class: type = Config) -> Flask:
    app = Flask(__name__)
    app.config.from_object(config_class)

    # Extensions
    db.init_app(app)
    app.config["SESSION_SQLALCHEMY"] = db  # required for sqlalchemy session backend
    Session(app)
    CSRFProtect(app)   # CSRF protection for all POST/PUT/DELETE forms

    # Blueprints
    app.register_blueprint(auth_bp)

    # ------------------------------------------------------------------
    # CLI
    # ------------------------------------------------------------------

    @app.cli.command("init-db")
    def init_db_command() -> None:
        """Create all database tables."""
        db.create_all()
        print("Database initialized.")

    # ------------------------------------------------------------------
    # Routes
    # ------------------------------------------------------------------

    @app.route("/")
    def index():
        if "user" not in session:
            return redirect(url_for("auth.login"))
        return redirect(url_for("dashboard"))

    @app.route("/dashboard")
    @login_required
    def dashboard():
        user_id = session["user"]["id"]
        notes = (
            Note.query.filter_by(owner_id=user_id)
            .order_by(Note.updated_at.desc())
            .all()
        )
        return render_template("dashboard.html", notes=notes)

    @app.route("/notes/new", methods=["GET", "POST"])
    @login_required
    def note_new():
        if request.method == "POST":
            title = request.form.get("title", "").strip()
            body = request.form.get("body", "").strip()
            if not title:
                flash("Title is required.", "danger")
            else:
                note = Note(
                    owner_id=session["user"]["id"],
                    title=title,
                    body=body,
                )
                db.session.add(note)
                db.session.commit()
                flash("Note created.", "success")
                return redirect(url_for("dashboard"))
        return render_template("note_form.html", note=None, action="Create")

    @app.route("/notes/<int:note_id>/edit", methods=["GET", "POST"])
    @login_required
    def note_edit(note_id: int):
        user_id = session["user"]["id"]
        # Ownership is enforced at the query level — returns 404 for another user's note.
        note = Note.query.filter_by(id=note_id, owner_id=user_id).first_or_404()
        if request.method == "POST":
            title = request.form.get("title", "").strip()
            body = request.form.get("body", "").strip()
            if not title:
                flash("Title is required.", "danger")
            else:
                note.title = title
                note.body = body
                db.session.commit()
                flash("Note updated.", "success")
                return redirect(url_for("dashboard"))
        return render_template("note_form.html", note=note, action="Update")

    @app.route("/notes/<int:note_id>/delete", methods=["POST"])
    @login_required
    def note_delete(note_id: int):
        user_id = session["user"]["id"]
        # Ownership enforced at the query level — another user's note returns 404.
        note = Note.query.filter_by(id=note_id, owner_id=user_id).first_or_404()
        db.session.delete(note)
        db.session.commit()
        flash("Note deleted.", "success")
        return redirect(url_for("dashboard"))

    return app


app = create_app()

if __name__ == "__main__":
    app.run(debug=True)
