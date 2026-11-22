FROM python:3.13-slim
LABEL org.opencontainers.image.source=https://github.com/mz-kara/hardened-kubernetes-platform

# Pas de fichiers .pyc écrits sur disque (compatible avec un système de fichiers
# en lecture seule) et logs envoyés directement sur la sortie standard.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Dépendances d'abord : Docker garde cette couche en cache tant que
# requirements.txt ne change pas, donc les rebuilds sont rapides.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Le code appartient à root et n'est que lisible par l'application :
# un attaquant qui prend le conteneur ne peut pas le modifier.
COPY app.py .
COPY templates/ templates/

# Utilisateur non-root, déclaré par NUMÉRO (et non par nom) pour que
# Kubernetes puisse vérifier runAsNonRoot. Aucun compte n'est créé :
# ce processus n'a besoin d'aucun fichier à lui.
USER 10001:10001

# Port > 1024 : pas besoin de privilège pour l'ouvrir.
EXPOSE 8080

# --worker-tmp-dir /dev/shm : Gunicorn écrit ses fichiers de contrôle en mémoire,
# ce qui permet readOnlyRootFilesystem côté Kubernetes.
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", \
     "--worker-tmp-dir", "/dev/shm", "--access-logfile", "-", "app:app"]
