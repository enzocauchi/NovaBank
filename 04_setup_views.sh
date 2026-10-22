#!/bin/bash
# 04_setup_views.sh - Étape 4 : Création des vues (Sécurité, Modifiables et Matérialisées)

set -e

echo "========================================="
echo "1. Création des Vues SQL"
echo "========================================="
sudo -u postgres psql -d novabank -c "
--------------------------------------------------
-- 1. VUE QUI CACHE DES DONNÉES
-- Cache le niveau de risque, le statut KYC, et masque une partie de l'email
--------------------------------------------------
CREATE OR REPLACE VIEW core.vw_safe_customers AS
SELECT 
    customer_id, 
    first_name, 
    last_name, 
    -- On garde les 3 premières lettres de l'email, on met des étoiles, et on garde la fin (.fr / .com)
    CONCAT(SUBSTRING(email FROM 1 FOR 3), '***@***', SUBSTRING(email FROM POSITION('.' IN email))) AS masked_email,
    birth_date
FROM core.customers;

--------------------------------------------------
-- 2. VUE MODIFIABLE AVEC LIMITE (WITH CHECK OPTION)
-- Permet de gérer uniquement les comptes actifs. 
-- Le CHECK OPTION interdit d'insérer un compte avec le statut 'CLOSED' via cette vue.
--------------------------------------------------
CREATE OR REPLACE VIEW core.vw_active_accounts AS
SELECT * 
FROM core.accounts 
WHERE status = 'ACTIVE'
WITH LOCAL CHECK OPTION;

--------------------------------------------------
-- 3. VUE ENREGISTRÉE (MATERIALIZED VIEW)
-- Calcule et stocke la richesse totale de chaque client.
-- Parfait pour les analystes : l'affichage est instantané sans recalculer à chaque fois.
--------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS core.mvw_customer_balances;
CREATE MATERIALIZED VIEW core.mvw_customer_balances AS
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    COUNT(a.account_id) AS total_accounts,
    SUM(a.balance) AS total_wealth
FROM core.customers c
JOIN core.accounts a ON c.customer_id = a.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name;

--------------------------------------------------
-- 4. GESTION DES DROITS SUR CES NOUVELLES VUES
--------------------------------------------------
GRANT SELECT ON core.vw_safe_customers TO appli, analyste, support;
GRANT SELECT, UPDATE, INSERT ON core.vw_active_accounts TO appli;
GRANT SELECT ON core.mvw_customer_balances TO analyste, auditeur;
"

echo "========================================="
echo "✅ Étape 4 terminée ! Les 3 vues obligatoires sont créées."
echo "========================================="
