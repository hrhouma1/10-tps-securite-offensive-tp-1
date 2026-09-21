#!/usr/bin/env bash
###############################################################################
# cleanup-lab.sh — Laboratoire 01 « Atelier Boréal »
# Arrête et supprime le conteneur du laboratoire, puis propose de supprimer
# l'image Docker et les données générées (.lab-data, secrets compris).
###############################################################################
set -euo pipefail

LAB_NAME="atelier-boreal-vps"
LAB_IMAGE="atelier-boreal-lab:1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DOCKER="docker"
if ! docker info >/dev/null 2>&1; then
  DOCKER="sudo docker"
fi

if $DOCKER ps -a --format '{{.Names}}' | grep -qx "$LAB_NAME"; then
  $DOCKER rm -f "$LAB_NAME" >/dev/null
  echo "[+] Conteneur « $LAB_NAME » supprimé."
else
  echo "[*] Aucun conteneur « $LAB_NAME » en cours."
fi

read -r -p "Supprimer aussi l'image « $LAB_IMAGE » ? [o/N] " rep_img
if [[ "$rep_img" =~ ^[oOyY]$ ]]; then
  $DOCKER rmi "$LAB_IMAGE" >/dev/null 2>&1 || true
  echo "[+] Image supprimée."
fi

read -r -p "Supprimer les données générées (.lab-data/, secrets compris) ? [o/N] " rep_data
if [[ "$rep_data" =~ ^[oOyY]$ ]]; then
  rm -rf "$SCRIPT_DIR/.lab-data"
  echo "[+] Dossier .lab-data/ supprimé."
fi

echo "[+] Nettoyage terminé."
