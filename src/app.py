"""
Guestbook : un livre d'or minimal.

- GET  /         affiche la page avec les messages
- POST /message  ajoute un message
- GET  /healthz  utilisé par Kubernetes pour savoir si le pod va bien

Les messages sont stockés dans Redis, dans une liste nommée "messages".
"""

import os

import redis
from flask import Flask, abort, redirect, render_template, request, url_for

# Où trouver Redis : un nom DNS (le Service Kubernetes "redis"), pas une IP.
REDIS_HOST = os.environ.get("REDIS_HOST", "redis")
REDIS_PORT = int(os.environ.get("REDIS_PORT", "6379"))

MAX_MESSAGE_LENGTH = 200   # refuse les messages trop longs
MAX_MESSAGES = 50          # on ne garde que les 50 derniers

app = Flask(__name__)
db = redis.Redis(
    host=REDIS_HOST,
    port=REDIS_PORT,
    decode_responses=True,   # renvoie des str au lieu de bytes
    socket_timeout=2,        # n'attend pas indéfiniment si Redis ne répond pas
)


@app.get("/")
def index():
    # LRANGE 0 -1 = toute la liste ; les plus récents sont en tête
    messages = db.lrange("messages", 0, -1)
    return render_template("index.html", messages=messages)


@app.post("/message")
def add_message():
    text = request.form.get("text", "").strip()
    if not text or len(text) > MAX_MESSAGE_LENGTH:
        abort(400)
    db.lpush("messages", text)                    # ajoute en tête de liste
    db.ltrim("messages", 0, MAX_MESSAGES - 1)     # coupe la liste à 50
    # Redirection après POST : un rafraîchissement ne renvoie pas le message
    return redirect(url_for("index"))


@app.get("/healthz")
def healthz():
    # Le pod n'est "prêt" que s'il arrive à joindre Redis
    try:
        db.ping()
    except redis.RedisError:
        return "redis unreachable", 503
    return "ok", 200
