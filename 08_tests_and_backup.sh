#!/bin/bash
# 08_tests_and_backup.sh - Étape 8 : Tests finaux et Sauvegarde (pg_dump)

echo "========================================="
echo "1. Tests de sécurité (Les erreurs rouges ci-dessous sont NORMALES !)"
echo "========================================="
# On désactive l'arrêt du script sur erreur (set +e) car on VEUT que ça échoue
set +e

echo -e "\n---> Test A : Tentative de création d'un client mineur (Doit être bloqué par CHECK) :"
sudo -u postgres psql -d novabank -c "INSERT INTO core.customers (first_name, last_name, email, birth_date) VALUES ('Enfant', 'Test', 'enfant@nova.fr', CURRENT_DATE);"

echo -e "\n---> Test B : Tentative de suppression du grand livre (Doit être bloqué par le Trigger) :"
sudo -u postgres psql -d novabank -c "DELETE FROM core.transactions WHERE tx_id = 1;"

# On réactive la sécurité du script
set -e

echo "========================================="
echo "2. Test d'un processus métier (Ouverture + Virement)"
echo "========================================="
sudo -u postgres psql -d novabank -c "
-- Création d'une cliente
INSERT INTO core.customers (first_name, last_name, email, birth_date) 
VALUES ('Marie', 'Curie', 'marie@novabank.fr', '1990-05-05');

-- Ouverture d'un compte avec 500€ via notre Procédure
CALL core.sp_open_account(2, 'EPARGNE', 500.00);

-- Virement de 100€ du compte N°1 (Jean) vers le compte N°2 (Marie)
CALL core.sp_make_transfer(1, 2, 100.00, 'Remboursement resto');
"
echo "✅ Ouverture de compte et Virement effectués avec succès via les procédures !"

echo "========================================="
echo "3. Sauvegarde de la base de données (pg_dump)"
echo "========================================="
# On exporte toute la structure et les données dans un fichier SQL
sudo -u postgres pg_dump --clean --if-exists novabank > novabank_backup.sql

echo "========================================="
echo "✅ Étape 8 terminée ! La sauvegarde 'novabank_backup.sql' est prête."
echo "========================================="
