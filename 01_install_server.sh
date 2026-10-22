#!/bin/bash
# 01_install_server.sh - Étape 1 : Installation et configuration serveur NovaBank

# Arrête le script immédiatement si une commande échoue
set -e

echo "========================================="
echo "1. Installation de PostgreSQL et UFW"
echo "========================================="
sudo apt-get update
# Installation de Postgres et du pare-feu (-y pour accepter automatiquement)
sudo apt-get install -y postgresql postgresql-contrib ufw

echo "========================================="
echo "2. Configuration du pare-feu (UFW)"
echo "========================================="
# ATTENTION : On autorise SSH en premier pour ne pas se bloquer dehors !
sudo ufw allow OpenSSH
# On ouvre le port par défaut de PostgreSQL
sudo ufw allow 5432/tcp
# On active le pare-feu
sudo ufw --force enable
sudo ufw status

echo "========================================="
echo "3. Sécurisation de pg_hba.conf"
echo "========================================="
# On récupère le chemin exact du fichier de configuration dynamiquement
PG_HBA=$(sudo -u postgres psql -t -P format=unaligned -c 'show hba_file;')

# On fait une sauvegarde de sécurité du fichier d'origine
sudo cp "$PG_HBA" "$PG_HBA.bak"

# On remplace le contenu du fichier par nos règles de sécurité strictes
sudo bash -c "cat > $PG_HBA" << EOL
# TYPE  DATABASE        USER            ADDRESS                 METHOD
# L'administrateur (postgres) se connecte localement sans mot de passe (via l'OS)
local   all             postgres                                peer
# Tous les autres utilisateurs locaux doivent utiliser un mot de passe chiffré
local   all             all                                     scram-sha-256
host    all             all             127.0.0.1/32            scram-sha-256
host    all             all             ::1/128                 scram-sha-256
EOL

# Redémarrage du service pour appliquer la nouvelle sécurité
sudo systemctl restart postgresql
# PostgreSQL se lancera désormais tout seul au démarrage de la VM
sudo systemctl enable postgresql

echo "========================================="
echo "✅ Étape 1 terminée avec succès !"
echo "========================================="
