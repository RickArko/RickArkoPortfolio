import json
from datetime import datetime
from flask import Flask, render_template, request
import constants
from loguru import logger

app = Flask(__name__)

@app.errorhandler(404) 
def not_found(e):
    return render_template("404.html")

@app.route('/')
@app.route('/home/')
def home():
    if request.method == 'GET':
        with open(constants.HOME_PATH) as f:
            home_data = json.load(f)
        return render_template('home.html', context=home_data)


@app.route('/experience/')
def experience():
    if request.method == 'GET':
        with open(constants.EXPERIENCE_PATH) as f:
            experience_data = json.load(f)
        return render_template('experience.html', context=experience_data)


@app.route('/blog/')
def blog():
    if request.method == 'GET':
        return render_template('blog.html')


@app.route('/projects/')
def projects():
    if request.method == 'GET':
        with open(constants.PROJECT_PATH) as f:
            projects_data = json.load(f)
        return render_template('projects.html', context=projects_data)


# @app.route('/contact/')
# def contact():
#     if request.method == 'GET':
#         with open(constants.CONTACT_PATH) as f:
#             contact_data = json.load(f)

#         logger.warning(f"Contact data loaded from: {contact_data}")
#         return render_template('contact.html', context=contact_data)
#         # return constants.CONTACT_PATH


application = app

if __name__ == "__main__":
    
    app.run(
        host="0.0.0.0",
        # host="127.0.0.1",
        port=8080,
        debug=True
    )