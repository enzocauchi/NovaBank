#!/bin/bash
# 06_setup_triggers.sh - Étape 6 : Triggers et automatisation PL/pgSQL

set -e

echo "========================================="
echo "1. Création des fonctions et triggers"
echo "========================================="
sudo -u postgres psql -d novabank -c "
--------------------------------------------------
-- TRIGGER 1 : MISE À JOUR AUTOMATIQUE DU SOLDE
--------------------------------------------------
CREATE OR REPLACE FUNCTION core.fn_update_balance() RETURNS TRIGGER AS \$\$
BEGIN
    IF NEW.tx_type = 'CREDIT' THEN
        UPDATE core.accounts 
        SET balance = balance + NEW.amount 
        WHERE account_id = NEW.account_id 
        RETURNING balance INTO NEW.balance_after;
    ELSIF NEW.tx_type = 'DEBIT' THEN
        -- Si le solde tombe sous 0, la contrainte CHECK de la table accounts bloquera tout !
        UPDATE core.accounts 
        SET balance = balance - NEW.amount 
        WHERE account_id = NEW.account_id 
        RETURNING balance INTO NEW.balance_after;
    END IF;
    RETURN NEW;
END;
\$\$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_balance
BEFORE INSERT ON core.transactions
FOR EACH ROW EXECUTE FUNCTION core.fn_update_balance();

--------------------------------------------------
-- TRIGGER 2 : LE PASSÉ NE CHANGE PLUS
--------------------------------------------------
CREATE OR REPLACE FUNCTION core.fn_protect_history() RETURNS TRIGGER AS \$\$
BEGIN
    RAISE EXCEPTION 'Interdit : L''historique comptable ne peut être ni modifié ni supprimé !';
END;
\$\$ LANGUAGE plpgsql;

CREATE TRIGGER trg_protect_history
BEFORE UPDATE OR DELETE ON core.transactions
FOR EACH ROW EXECUTE FUNCTION core.fn_protect_history();

--------------------------------------------------
-- TRIGGER 3 : DÉTECTION DE FRAUDE (Règles automatiques)
--------------------------------------------------
CREATE OR REPLACE FUNCTION core.fn_detect_fraud() RETURNS TRIGGER AS \$\$
DECLARE
    v_recent_tx_count INT;
BEGIN
    -- Règle 1 : Retrait de 5000 ou plus
    IF NEW.tx_type = 'DEBIT' AND NEW.amount >= 5000 THEN
        INSERT INTO core.fraud_alerts(account_id, tx_id, rule_code)
        VALUES (NEW.account_id, NEW.tx_id, 'RETRAIT_MASSIF_>_5000');
    END IF;

    -- Règle 2 : 5 retraits/virements en moins de 10 minutes
    SELECT COUNT(*) INTO v_recent_tx_count
    FROM core.transactions
    WHERE account_id = NEW.account_id
      AND tx_type = 'DEBIT'
      AND created_at >= (CURRENT_TIMESTAMP - INTERVAL '10 minutes');

    IF v_recent_tx_count >= 5 THEN
        INSERT INTO core.fraud_alerts(account_id, tx_id, rule_code)
        VALUES (NEW.account_id, NEW.tx_id, 'HAUTE_FREQUENCE_>_5_EN_10MIN');
    END IF;

    RETURN NEW;
END;
\$\$ LANGUAGE plpgsql;

-- On le lance AFTER INSERT, car on a besoin que la transaction soit validée
CREATE TRIGGER trg_detect_fraud
AFTER INSERT ON core.transactions
FOR EACH ROW EXECUTE FUNCTION core.fn_detect_fraud();

--------------------------------------------------
-- TRIGGER 4 : JOURNAL D'AUDIT (Traçabilité)
--------------------------------------------------
CREATE OR REPLACE FUNCTION audit.fn_audit_log() RETURNS TRIGGER AS \$\$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        INSERT INTO audit.audit_log(table_name, operation, old_data, new_data)
        -- row_to_json permet de capturer toute la ligne avant/après sous format JSON
        VALUES (TG_TABLE_NAME, TG_OP, row_to_json(OLD), row_to_json(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit.audit_log(table_name, operation, old_data)
        VALUES (TG_TABLE_NAME, TG_OP, row_to_json(OLD));
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
\$\$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_customers
AFTER UPDATE OR DELETE ON core.customers
FOR EACH ROW EXECUTE FUNCTION audit.fn_audit_log();

CREATE TRIGGER trg_audit_accounts
AFTER UPDATE OR DELETE ON core.accounts
FOR EACH ROW EXECUTE FUNCTION audit.fn_audit_log();
"

echo "========================================="
echo "✅ Étape 6 terminée ! Les triggers sont activés."
echo "========================================="
