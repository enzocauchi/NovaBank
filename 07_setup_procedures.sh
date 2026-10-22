#!/bin/bash
# 07_setup_procedures.sh - Étape 7 : Création des Procédures (Virement, Compte, Relevé)

set -e

echo "========================================="
echo "1. Création des Procédures PL/pgSQL"
echo "========================================="
sudo -u postgres psql -d novabank -c "
--------------------------------------------------
-- PROCÉDURE 1 : LE VIREMENT SÉCURISÉ (TOUT OU RIEN)
--------------------------------------------------
CREATE OR REPLACE PROCEDURE core.sp_make_transfer(
    p_from_account INT,
    p_to_account INT,
    p_amount DECIMAL,
    p_label VARCHAR
)
LANGUAGE plpgsql
AS \$\$
DECLARE
    v_transfer_id INT;
BEGIN
    -- 1. On enregistre la trace du virement
    INSERT INTO core.transfers (from_account_id, to_account_id, amount, label)
    VALUES (p_from_account, p_to_account, p_amount, p_label)
    RETURNING transfer_id INTO v_transfer_id;

    -- 2. On crée l'écriture de DÉBIT pour l'expéditeur
    -- Le montant passe par le Trigger de l'Étape 6 qui va déduire le solde.
    -- Si le solde tombe sous 0, le CHECK bloque tout et la transaction s'annule (Rollback) !
    INSERT INTO core.transactions (account_id, tx_type, amount, balance_after, transfer_id)
    VALUES (p_from_account, 'DEBIT', p_amount, 0, v_transfer_id);

    -- 3. On crée l'écriture de CRÉDIT pour le destinataire
    INSERT INTO core.transactions (account_id, tx_type, amount, balance_after, transfer_id)
    VALUES (p_to_account, 'CREDIT', p_amount, 0, v_transfer_id);
    
    -- Si on arrive ici sans erreur, la base valide définitivement (Commit).
END;
\$\$;

--------------------------------------------------
-- PROCÉDURE 2 : OUVERTURE D'UN COMPTE AVEC DÉPÔT INITIAL
--------------------------------------------------
CREATE OR REPLACE PROCEDURE core.sp_open_account(
    p_customer_id INT,
    p_account_type VARCHAR,
    p_initial_deposit DECIMAL
)
LANGUAGE plpgsql
AS \$\$
DECLARE
    v_account_id INT;
    v_iban VARCHAR;
BEGIN
    -- Génération d'un IBAN fictif unique basé sur l'heure de la machine
    v_iban := 'FR76' || LPAD((EXTRACT(EPOCH FROM clock_timestamp()) * 100)::BIGINT::TEXT, 23, '0');
    
    -- On crée le compte à 0€
    INSERT INTO core.accounts (customer_id, iban, account_type, balance)
    VALUES (p_customer_id, v_iban, p_account_type, 0)
    RETURNING account_id INTO v_account_id;

    -- S'il y a un dépôt initial, on fait un versement
    IF p_initial_deposit > 0 THEN
        INSERT INTO core.transactions (account_id, tx_type, amount, balance_after)
        VALUES (v_account_id, 'CREDIT', p_initial_deposit, 0);
    END IF;
END;
\$\$;

--------------------------------------------------
-- PROCÉDURE 3 (FONCTION) : LE RELEVÉ BANCAIRE
--------------------------------------------------
-- On utilise FUNCTION car elle doit retourner un tableau de résultats (TABLE)
CREATE OR REPLACE FUNCTION core.fn_get_statement(p_account_id INT)
RETURNS TABLE (
    date_operation TIMESTAMP,
    type_operation VARCHAR,
    montant DECIMAL,
    solde_apres DECIMAL
)
LANGUAGE plpgsql
AS \$\$
BEGIN
    RETURN QUERY
    SELECT created_at, tx_type, amount, balance_after
    FROM core.transactions
    WHERE account_id = p_account_id
    ORDER BY created_at DESC
    LIMIT 30; -- Affiche les 30 dernières opérations
END;
\$\$;

--------------------------------------------------
-- Autorisation d'utilisation pour l'application
--------------------------------------------------
GRANT EXECUTE ON PROCEDURE core.sp_make_transfer TO appli;
GRANT EXECUTE ON PROCEDURE core.sp_open_account TO appli;
GRANT EXECUTE ON FUNCTION core.fn_get_statement TO appli;
"

echo "========================================="
echo "✅ Étape 7 terminée ! Les procédures bancaires sont prêtes."
echo "========================================="
