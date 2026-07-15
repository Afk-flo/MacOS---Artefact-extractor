#!/bin/bash
# Collection d'artefact sous MacOS Apple Silicon 

####
# TODO : 
# - Horodatage et traçabilité améliorée 
# - Ajout d'éléments essentiels de collecte
####

set -u 

echo "-----------------------------------"
echo " MacOS Artifact extraction tool    "
echo "-----------------------------------"
echo " "
echo "[!] Début du script ..."

# ==== Informations ==== #
CASE="IR_$(hostname -s)_$(date -u +%Y%m%dT%H%M%SZ)"
IR="/tmp/$CASE"

if [ "$(id -u)" -ne 0 ]; then echo "[X] Merci de lancer le script en Root."; exit 1; fi
if [ ! -d "/tmp" ]; then echo "[X] Le repertoire /tmp n'est pas accessible."; exit 1; fi

mkdir -p "$IR"/{system/volatile,vmaps,proc_dumps,history,unified_logs,persistance,artifacts}
echo "[!] Création des dossiers d'extractions dans $IR"

exec > >(tee -a "$IR/00_transcript.log") 2>&1

log(){ echo "[$(date -u +%H:%M:%SZ)] $*"; }
run(){ echo "### CMD: $*"; "$@"; echo; }

echo " " 
log "=== DEBUT COLLECTE ==="
log "Opérateur euid=$(id -u) ($(whoami))   Host=$(hostname)   PIDs cibles: ${*:-<aucun>}"

# === Contexte Système === # 
echo " "
log "[1] Contexte Système"
{
    run date -u
    run sw_vers
    run uname -a
    run sysctl -h hw.model kern.osversion kern.bootargs machdep.cpu.brand_string
    run csrutil status
    run spctl --status
    run uptime
    run system_profiler SPHardwareDataType SPStorageDataType
    run nvram -p
} > "$IR/system/system_context.txt" 2>&1

echo "[!] Taille $(du -sh $IR/system/system_context.txt)"
echo "[!] Nombre de lignes $(wc -l $IR/system/system_context.txt)"

