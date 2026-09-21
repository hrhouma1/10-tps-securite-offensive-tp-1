#!/usr/bin/env bash
###############################################################################
# setup-lab.sh — Laboratoire 01 « Atelier Boréal »
#
# Crée un VPS de laboratoire (conteneur Docker local) exposant :
#   - FTP  (port 21) : accès anonyme, fichiers locks.txt et task.txt
#   - SSH  (port 22) : compte de test (mot de passe présent dans locks.txt)
#   - HTTP (port 80) : page « Atelier Boréal » avec jeton de vérification
#
# Usage :
#   bash setup-lab.sh            # déploiement local (IP du conteneur)
#   bash setup-lab.sh --publish  # publie les ports sur l'hôte (mode VPS dédié)
#
# Aucun secret n'est stocké dans le dépôt : tout est généré dans .lab-data/
# (ignoré par git). Le mot de passe et les jetons sont régénérés à chaque
# exécution du script : chaque groupe dispose donc d'identifiants différents.
###############################################################################
set -euo pipefail

# ---------------------------------------------------------------------------
# Paramètres modifiables par l'enseignant
# ---------------------------------------------------------------------------
LAB_NAME="atelier-boreal-vps"          # nom du conteneur
LAB_IMAGE="atelier-boreal-lab:1.0"     # nom de l'image Docker
LAB_HOSTNAME="atelier-boreal-vps"      # hostname vu par les étudiants en SSH
LAB_USER="${LAB_USER:-lin}"            # compte de test du laboratoire
PUBLISH=0

[ "${1:-}" = "--publish" ] && PUBLISH=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/.lab-data"

# ---------------------------------------------------------------------------
# Compatibilité Git Bash / Windows (MSYS2) : sans précaution, MSYS2 réécrit
# les arguments contenant ':' (ex. -v /hote:/conteneur:ro) et casse Docker.
# Sous Linux/Kali, cygpath n'existe pas : le comportement est inchangé.
# ---------------------------------------------------------------------------
if command -v cygpath >/dev/null 2>&1; then
  export MSYS_NO_PATHCONV=1
  export MSYS2_ARG_CONV_EXCL='*'
  DOCKER_DATA_DIR="$(cygpath -m "$DATA_DIR")"   # ex. C:/Users/... (compris par Docker Desktop)
else
  DOCKER_DATA_DIR="$DATA_DIR"
fi

info() { printf '\033[1;34m[*]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[-]\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 1. Vérification de Docker
# ---------------------------------------------------------------------------
command -v docker >/dev/null 2>&1 \
  || die "Docker introuvable. Sur Kali : sudo apt update && sudo apt install -y docker.io"

DOCKER="docker"
if ! docker info >/dev/null 2>&1; then
  if sudo docker info >/dev/null 2>&1; then
    DOCKER="sudo docker"
  else
    die "Le service Docker ne répond pas. Lancez : sudo systemctl start docker"
  fi
fi
info "Docker détecté (commande : $DOCKER)."

# ---------------------------------------------------------------------------
# 2. Génération des secrets et des fichiers (jamais commités : cf. .gitignore)
# ---------------------------------------------------------------------------
info "Génération des fichiers du laboratoire dans .lab-data/ ..."
rm -rf "$DATA_DIR"
mkdir -p "$DATA_DIR/ftp" "$DATA_DIR/www"
chmod 700 "$DATA_DIR"

# Liste de mots de passe FICTIFS du laboratoire (thème nature / sciences).
# Le « vrai » mot de passe est l'un de ces mots, choisi au hasard : il est
# donc garanti présent dans locks.txt, à une position aléatoire, et il est
# différent à chaque déploiement.
WORDLIST=(
  sunshine mountain river forest moonlight starlight ocean breeze thunder
  lightning raindrop snowflake rainbow sunrise sunset twilight dawn dusk
  horizon galaxy nebula comet meteor asteroid planet star moon earth mars
  jupiter saturn uranus neptune pluto cosmos universe gravity orbit eclipse
  nova supernova quasar pulsar blackhole wormhole darkmatter darkenergy
  bigbang singularity spacetime relativity quantum photon electron neutron
  proton atom molecule element compound reaction catalyst enzyme protein
  amino acid base solution solvent solute mixture alloy metal nonmetal
  metalloid conductor insulator semiconductor resistor capacitor inductor
  transistor diode circuit voltage current power energy force mass weight
  density volume pressure temperature thermal radiation conduction convection
  insulation reflection refraction diffraction interference polarization
  dispersion absorption emission transmission scattering fluorescence
  phosphorescence luminescence incandescence bioluminescence glacier iceberg
  avalanche summit meadow prairie tundra savanna canyon plateau volcano
  crater lagoon reef coral tide wave foam pebble granite basalt
  quartz obsidian amber ivory cedar willow birch maple pine spruce falcon
  eagle sparrow raven heron salmon trout beaver otter lynx wolf bear moose
  caribou bison
)

LAB_PASSWORD="$(printf '%s\n' "${WORDLIST[@]}" | shuf -n 1)"

# locks.txt : la liste mélangée (le bon mot de passe y figure par construction)
printf '%s\n' "${WORDLIST[@]}" | shuf > "$DATA_DIR/ftp/locks.txt"

# task.txt : l'indice qui désigne le compte autorisé
cat > "$DATA_DIR/ftp/task.txt" <<EOF
Objet : vérification de l'ancien serveur de test
De : direction@atelier-boreal.example
À : équipe technique

Bonjour,

L'ancien serveur de test reste en ligne le temps de la migration.
Le seul compte autorisé à s'y connecter pour la vérification est : ${LAB_USER}

Les anciens mots de passe de test sont consignés dans le fichier locks.txt.
Utilisez-les avec précaution et ne les partagez pas en dehors de l'équipe.
Merci de ne rien modifier sur le serveur.

— L'équipe Atelier Boréal
EOF

chmod 444 "$DATA_DIR/ftp/locks.txt" "$DATA_DIR/ftp/task.txt"

# Jetons de preuve, uniques à chaque instance
# (od lit un nombre fixe d'octets : pas de SIGPIPE avec 'set -o pipefail')
WEB_TOKEN="BOREAL-WEB-$(od -An -N4 -tx4 /dev/urandom | tr -d ' \n')"
SSH_TOKEN="BOREAL-SSH-$(od -An -N4 -tx4 /dev/urandom | tr -d ' \n')"

# Page Web du faux serveur
cat > "$DATA_DIR/www/index.html" <<'EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <title>Atelier Boréal — Serveur de test</title>
  <style>
    body { font-family: sans-serif; max-width: 640px; margin: 4em auto; color: #333; }
    h1 { color: #1a5276; }
    code { background: #eef3f7; padding: .2em .5em; border-radius: 4px; }
    .note { color: #777; font-size: .9em; }
  </style>
</head>
<body>
  <h1>Atelier Boréal</h1>
  <p>Ancien serveur de test — en cours de migration vers la nouvelle plateforme.</p>
  <p>Nœud : <code>__LAB_HOSTNAME__</code></p>
  <p>Jeton de vérification : <code>__WEB_TOKEN__</code></p>
  <p class="note">Accès réservé à l'équipe technique. Toute activité est consignée.</p>
</body>
</html>
EOF
sed -i "s/__LAB_HOSTNAME__/$LAB_HOSTNAME/; s/__WEB_TOKEN__/$WEB_TOKEN/" "$DATA_DIR/www/index.html"

# Variables injectées dans le conteneur au démarrage (secret local uniquement)
cat > "$DATA_DIR/lab.env" <<EOF
LAB_USER=${LAB_USER}
LAB_PASSWORD=${LAB_PASSWORD}
SSH_TOKEN=${SSH_TOKEN}
EOF
chmod 600 "$DATA_DIR/lab.env"

# Récapitulatif réservé à l'enseignant
cat > "$DATA_DIR/secret.txt" <<EOF
Laboratoire 01 — Atelier Boréal (NE PAS PARTAGER AUX ÉTUDIANTS)
================================================================
Compte de test     : ${LAB_USER}
Mot de passe SSH   : ${LAB_PASSWORD}
Jeton HTTP         : ${WEB_TOKEN}
Jeton SSH (bonus)  : ${SSH_TOKEN}
Généré le          : $(date)
EOF
chmod 600 "$DATA_DIR/secret.txt"

ok "Secrets générés (réservés à l'enseignant : .lab-data/secret.txt)."

# ---------------------------------------------------------------------------
# 3. Fichiers Docker (générés, sans aucun secret)
# ---------------------------------------------------------------------------
cat > "$DATA_DIR/Dockerfile" <<'EOF'
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      vsftpd \
      openssh-server \
      nginx-light \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /srv/ftp /run/sshd /var/run/vsftpd/empty

COPY vsftpd.conf /etc/vsftpd.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 21 22 80
ENTRYPOINT ["/entrypoint.sh"]
EOF

cat > "$DATA_DIR/vsftpd.conf" <<'EOF'
listen=YES
listen_ipv6=NO
anonymous_enable=YES
local_enable=NO
write_enable=NO
anon_upload_enable=NO
anon_mkdir_write_enable=NO
anon_other_write_enable=NO
anon_root=/srv/ftp
anon_world_readable_only=YES
hide_ids=YES
pasv_enable=YES
pasv_min_port=30000
pasv_max_port=30009
seccomp_sandbox=NO
EOF

cat > "$DATA_DIR/entrypoint.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

LAB_USER="${LAB_USER:-lin}"
: "${LAB_PASSWORD:?Variable LAB_PASSWORD manquante}"

# Compte de test du laboratoire (sans privilèges, sudo non installé)
if ! id "$LAB_USER" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "$LAB_USER"
fi
echo "${LAB_USER}:${LAB_PASSWORD}" | chpasswd

# Jeton de preuve à relever pendant l'étape SSH (question bonus)
if [ -n "${SSH_TOKEN:-}" ]; then
  printf 'Jeton de preuve SSH du laboratoire 01 : %s\n' "$SSH_TOKEN" \
    > "/home/${LAB_USER}/preuve-lab.txt"
  chown "${LAB_USER}:${LAB_USER}" "/home/${LAB_USER}/preuve-lab.txt"
  chmod 644 "/home/${LAB_USER}/preuve-lab.txt"
fi

mkdir -p /run/sshd /var/run/vsftpd/empty
/usr/sbin/sshd
/usr/sbin/vsftpd &
exec /usr/sbin/nginx -g 'daemon off;'
EOF
chmod +x "$DATA_DIR/entrypoint.sh"

# ---------------------------------------------------------------------------
# 4. Construction et démarrage du « VPS »
# ---------------------------------------------------------------------------
info "Construction de l'image ${LAB_IMAGE} (la première fois peut prendre quelques minutes)..."
$DOCKER build -t "$LAB_IMAGE" "$DOCKER_DATA_DIR"
ok "Image construite."

if $DOCKER ps -a --format '{{.Names}}' | grep -qx "$LAB_NAME"; then
  warn "Un conteneur « $LAB_NAME » existe déjà : il est arrêté et remplacé."
  $DOCKER rm -f "$LAB_NAME" >/dev/null
fi

RUN_ARGS=(
  -d
  --name "$LAB_NAME"
  --hostname "$LAB_HOSTNAME"
  --env-file "$DOCKER_DATA_DIR/lab.env"
  -v "$DOCKER_DATA_DIR/ftp:/srv/ftp:ro"
  -v "$DOCKER_DATA_DIR/www:/var/www/html:ro"
)

if [ "$PUBLISH" -eq 1 ]; then
  warn "Mode --publish : les ports 21, 22 et 80 seront exposés sur TOUTES les interfaces de l'hôte."
  warn "Assurez-vous que le SSH de l'hôte n'occupe pas déjà le port 22 !"
  RUN_ARGS+=( -p 21:21 -p 22:22 -p 80:80 -p 30000-30009:30000-30009 )
fi

$DOCKER run "${RUN_ARGS[@]}" "$LAB_IMAGE" >/dev/null
sleep 2

IP="$($DOCKER inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$LAB_NAME")"
[ -n "$IP" ] || die "Impossible de récupérer l'adresse IP du conteneur."

# ---------------------------------------------------------------------------
# 5. Tests de fumée (via curl : portable Kali, Debian/Ubuntu et Git Bash)
# ---------------------------------------------------------------------------
info "Vérification des services..."

check_banner() {  # $1=port  $2=nom du service
  local out
  out="$(curl -s --max-time 3 "telnet://$IP:$1" 2>/dev/null || true)"
  out="${out%%$'\n'*}"
  if [ -n "$out" ]; then
    ok "port $1 ($2) : $out"
  else
    warn "port $1 ($2) ne répond pas encore (patientez puis vérifiez avec nmap)"
  fi
}

check_banner 21 FTP
check_banner 22 SSH

HTTP_CODE="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "http://$IP/" || true)"
if [ "$HTTP_CODE" = "200" ]; then
  ok "port 80 (HTTP) : réponse $HTTP_CODE"
else
  warn "port 80 (HTTP) ne répond pas encore (patientez puis vérifiez avec curl)"
fi

# ---------------------------------------------------------------------------
# 6. Résumé
# ---------------------------------------------------------------------------
cat <<EOF

======================================================================
  VPS DE LABORATOIRE PRÊT — « Atelier Boréal »
======================================================================
  Adresse IP cible :  ${IP}
  Services exposés :  FTP (21) · SSH (22) · HTTP (80)

  Pour commencer :
    export IP=${IP}
    puis suivez les étapes du README.md

  Rappel : il est INTERDIT d'inspecter le conteneur (docker exec,
  docker inspect, docker logs) ou de lire le dossier .lab-data/ —
  agissez comme si le serveur était distant.
----------------------------------------------------------------------
  Enseignant : mot de passe et jetons dans .lab-data/secret.txt
  Nettoyage  : bash cleanup-lab.sh
======================================================================
EOF
