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

mkdir -p "$IR"/{system,volatile,vmmaps,proc_dumps,history,unified_logs,persistance,artifacts}
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

# === Mem 1 === #
# Action prè SIP

echo " " 
log "[2] Etat mémoire : process / réseau / handles"

ps -axww -o pid,ppid,uid,gid,pcpu,pmem,lstart,tt,state,command > "$IR/volatile/ps_full.txt" 2>&1
ps -axeww -o pid,command                                       > "$IR/volatile/ps_env.txt" 2>&1
lsof -nP                                                       > "$IR/volatile/lsof_all.txt" 2>&1
lsof -i -nP                                                    > "$IR/volatile/lsof_net.txt" 2>&1
netstat -anv                                                   > "$IR/volatile/netstat.txt" 2>&1
netstat -rn                                                    > "$IR/volatile/routes.txt" 2>&1
arp -an                                                        > "$IR/volatile/arp.txt" 2>&1
scutil --dns                                                   > "$IR/volatile/dns.txt" 2>&1 
nettop -P -L 1                                                 > "$IR/volatile/nettop.txt" 2>&1
kexstat                                                        > "$IR/volatile/kexstat.txt" 2>&1
systemextensionsctl list                                       > "$IR/volatile/kexstat.txt" 2>&1
launchctl list                                                 > "$IR/volatile/launchctl.txt" 2>&1
dscl . -list /Users                                            > "$IR/volatile/users.txt" 2>&1
dscl . -read /Groups/admin GroupMembership                     > "$IR/volatile/admins.txt" 2>&1
who -a                                                         > "$IR/volatile/who.txt" 2>&1
last -50                                                       > "$IR/volatile/last.txt" 2>&1

echo "[!] Taille "
echo "$(du -sh $IR/volatile/* | sort -rh)"

# === DUMP process (att!) === # 
# ! tout n'est pas présent, pas le content

echo " "
log "[3] vmmap de tous les process (métadata)"
for pid in $(ps ax -o pid=); do
    vmmap -v "$pid" > "$IR/vmmaps/vmmap_${pid}.txt" 2>/dev/null
done 

echo "[!] Taille "
echo "$(du -sh $IR/vmmaps/)" # pas chaque car ça peut monter à plusieurs centaines (sur test 2/3Gb)


# === Dump PID suspects (todo) === #

# === Historiques Shell & Artefacts User === #
echo " " 
log "[5] Historiques shell" 

for home in /Users/*; do
    [ -d "$home" ] || continue

    u="$(basename "$home")"
    dst="$IR/history/$u"; mkdir -p "$dst"

    for f in .bash_history .sh_history .bash_sessions .zsh_sessions .python_history; do
        [ -e "$home/$f" ] && cp -a "$home/$f" "$dst/" 2>/dev/null 
    done 
    
    # SSH 
    [ -d "$home/.ssh" ] && cp -a "$home/.ssh" "$dst/ssh_dir" 2>/dev/null
done 

echo "[!] Taille "
echo "$(du -sh $IR/history/)" 


