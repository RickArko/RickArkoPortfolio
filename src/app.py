import json
from flask import Flask, render_template
import constants

app = Flask(__name__)


@app.errorhandler(404)
def not_found(e):
    return render_template("404.html"), 404


@app.route("/")
@app.route("/home/")
def home():
    with open(constants.HOME_PATH) as f:
        home_data = json.load(f)
    return render_template("home.html", context=home_data)


@app.route("/experience/")
def experience():
    with open(constants.EXPERIENCE_PATH) as f:
        experience_data = json.load(f)
    return render_template("experience.html", context=experience_data)


@app.route("/blog/")
def blog():
    return render_template("blog.html")


@app.route("/projects/")
def projects():
    with open(constants.PROJECT_PATH) as f:
        projects_data = json.load(f)
    return render_template("projects.html", context=projects_data)


@app.route("/contact/")
def contact():
    return render_template("contact.html")


@app.route("/health")
def health():
    return {"status": "ok"}


application = app

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=True)
