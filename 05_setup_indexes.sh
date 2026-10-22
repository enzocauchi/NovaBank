#!/bin/bash
# 05_setup_indexes.sh - Étape 5 : Création des index et tests de performance

set -e

echo "========================================="
echo "1. Test de performance AVANT les index"
echo "========================================="
echo "Recherche des transactions récentes du compte N°1 (sur 1 million de lignes)..."
sudo -u postgres psql -d novabank -c "
-- EXPLAIN ANALYZE exécute la requête et affiche son temps réel d'exécution
EXPLAIN ANALYZE 
SELECT * FROM core.transactions 
WHERE account_id = 1 
ORDER BY created_at DESC 
LIMIT 50;
"

echo "========================================="
echo "2. Création des 4 Index stratégiques"
echo "========================================="
sudo -u postgres psql -d novabank -c "
-- Index 1 : Pour accélérer l'affichage de l'historique d'un compte précis
CREATE INDEX idx_transactions_account_id ON core.transactions(account_id);

-- Index 2 : Pour accélérer les recherches par date (très fréquent en banque)
CREATE INDEX idx_transactions_created_at ON core.transactions(created_at);

-- Index 3 : Pour accélérer la connexion d'un client via son email
CREATE INDEX idx_customers_email ON core.customers(email);

-- Index 4 : Pour retrouver rapidement tous les virements émis par un compte
CREATE INDEX idx_transfers_from_account ON core.transfers(from_account_id);
"

echo "========================================="
echo "3. Test de performance APRÈS les index"
echo "========================================="
echo "Même recherche... regarde la différence sur 'Execution Time' !"
sudo -u postgres psql -d novabank -c "
EXPLAIN ANALYZE 
SELECT * FROM core.transactions 
WHERE account_id = 1 
ORDER BY created_at DESC 
LIMIT 50;
"

echo "========================================="
echo "✅ Étape 5 terminée ! Les requêtes sont optimisées."
echo "========================================="
