# Guestbook — application cible du cluster durci

Un livre d'or minimal : une page web où l'on poste un message, qui s'affiche
ensuite dans la liste. L'application est volontairement simple ; elle sert de
**cible** pour démontrer les couches de sécurité du cluster.

## Architecture

```
Navigateur (hôte)
   │  http://<IP-worker>:30080
   ▼
Service "web" (NodePort 30080)          ← seule porte ouverte vers l'extérieur
   ▼
Pod web  ── Flask + Gunicorn, port 8080, UID 10001
   │  se connecte à "redis:6379"
   │  (le nom "redis" est traduit en IP par CoreDNS, dans kube-system)
   ▼
Service "redis" (ClusterIP)             ← joignable uniquement dans le cluster
   ▼
Pod redis ── Redis 7.4, port 6379, UID 999, données dans /data
```

Deux pods, deux Services, un namespace. Les pods sont repérés par leurs labels :

| Pod   | Labels                               |
|-------|--------------------------------------|
| web   | `app: guestbook`, `tier: frontend`   |
| redis | `app: guestbook`, `tier: backend`    |

## Le code

| Fichier                | Rôle |
|------------------------|------|
| `app.py`               | l'application : 3 routes (`/`, `/message`, `/healthz`) |
| `templates/index.html` | la page HTML |
| `requirements.txt`     | les dépendances Python, versions figées |
| `Dockerfile`           | la recette de l'image |

Ce que fait chaque route :

- `GET /` lit la liste `messages` dans Redis (`LRANGE`) et affiche la page.
- `POST /message` ajoute le message en tête de liste (`LPUSH`), garde les
  50 derniers (`LTRIM`), puis redirige vers `/`.
- `GET /healthz` répond `200` si Redis répond, `503` sinon. Kubernetes s'en sert
  pour savoir si le pod est prêt à recevoir du trafic.

Pour voir les données directement dans Redis :

```bash
kubectl exec -n guestbook deploy/redis -- redis-cli LRANGE messages 0 -1
```

## Choix de sécurité dans l'image

- **Base `python:3.13-slim`** : Debian récente et maintenue, sans outils superflus.
- **`USER 10001:10001`** : non-root, déclaré par numéro pour que `runAsNonRoot`
  puisse être vérifié par Kubernetes.
- **Code appartenant à root, en lecture seule pour l'appli** : un attaquant qui
  prend le conteneur ne peut pas modifier le code.
- **Port 8080** : aucun privilège nécessaire pour l'ouvrir.
- **Aucune écriture sur disque** (`PYTHONDONTWRITEBYTECODE`, Gunicorn dans
  `/dev/shm`) : compatible avec `readOnlyRootFilesystem`.
- **Échappement HTML automatique** (Jinja) : un message `<script>` s'affiche
  comme du texte, pas de XSS.

## Construire et déployer

Le cluster n'a pas de registre d'images : on construit sur l'hôte, puis on
importe l'image directement dans containerd sur le worker.

**1. Sur l'hôte : construire et exporter l'image**

```bash
cd ~/k8s_project/app
docker build -t guestbook-web:v1 .
docker save guestbook-web:v1 -o ~/k8s_project/guestbook-web-v1.tar
```

**2. Sur le worker : importer l'image**

```bash
vagrant ssh k8s-worker
sudo ctr -n k8s.io images import /vagrant/guestbook-web-v1.tar
sudo crictl images | grep guestbook      # doit afficher guestbook-web v1
exit
```

`-n k8s.io` : c'est l'espace de noms de containerd utilisé par Kubernetes.
Sans lui, l'image est importée mais le kubelet ne la voit pas.

**3. Sur le master : déployer**

```bash
kubectl delete ns guestbook                  # supprime l'ancienne appli Google
kubectl apply -f /vagrant/kubernetes/app/guestbook.yml
kubectl get pods -n guestbook -w
```

Le Deployment `web` utilise `imagePullPolicy: Never` : Kubernetes n'essaie pas
de télécharger l'image et utilise celle importée. Si elle manque, le pod
affiche `ErrImageNeverPull`.

**4. Tester** : `http://<IP-host-only-du-worker>:30080`

## Mettre à jour l'application

Après une modification du code, changer le tag (`v2`), puis refaire les
étapes 1 et 2 avec ce tag, mettre à jour `image:` dans le manifeste et
réappliquer. On évite `latest` : on sait toujours quelle version tourne.
