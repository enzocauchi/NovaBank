#!/bin/bash
# 02_setup_database.sh - Étape 2 : Schéma et génération des données NovaBank

set -e

echo "========================================="
echo "1. Création de la base de données NovaBank"
echo "========================================="
sudo -u postgres psql -c "DROP DATABASE IF EXISTS novabank;"
sudo -u postgres psql -c "CREATE DATABASE novabank;"

echo "========================================="
echo "2. Création des tables et des contraintes"
echo "========================================="
sudo -u postgres psql -d novabank -c "
CREATE SCHEMA core;
CREATE SCHEMA audit;

-- 1. CLIENTS
CREATE TABLE core.customers (
    customer_id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL CHECK (email ~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$'),
    phone VARCHAR(20),
    birth_date DATE NOT NULL CHECK (birth_date <= CURRENT_DATE - INTERVAL '18 years'),
    kyc_status VARCHAR(50) DEFAULT 'PENDING',
    risk_level VARCHAR(50) DEFAULT 'LOW',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. COMPTES
CREATE TABLE core.accounts (
    account_id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES core.customers(customer_id),
    iban VARCHAR(34) UNIQUE NOT NULL,
    account_type VARCHAR(50) NOT NULL,
    balance DECIMAL(15, 2) NOT NULL DEFAULT 0.00 CHECK (balance >= 0),
    status VARCHAR(20) DEFAULT 'ACTIVE',
    opened_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. VIREMENTS
CREATE TABLE core.transfers (
    transfer_id SERIAL PRIMARY KEY,
    from_account_id INT REFERENCES core.accounts(account_id),
    to_account_id INT REFERENCES core.accounts(account_id),
    amount DECIMAL(15, 2) NOT NULL CHECK (amount > 0),
    label VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (from_account_id != to_account_id)
);

-- 4. ÉCRITURES (GRAND LIVRE)
CREATE TABLE core.transactions (
    tx_id SERIAL PRIMARY KEY,
    account_id INT REFERENCES core.accounts(account_id),
    tx_type VARCHAR(10) CHECK (tx_type IN ('CREDIT', 'DEBIT')),
    amount DECIMAL(15, 2) NOT NULL CHECK (amount > 0),
    balance_after DECIMAL(15, 2) NOT NULL,
    transfer_id INT REFERENCES core.transfers(transfer_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. ALERTES
CREATE TABLE core.fraud_alerts (
    alert_id SERIAL PRIMARY KEY,
    account_id INT REFERENCES core.accounts(account_id),
    tx_id INT REFERENCES core.transactions(tx_id),
    rule_code VARCHAR(100) NOT NULL,
    status VARCHAR(20) DEFAULT 'NEW',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 6. JOURNAL D'AUDIT
CREATE TABLE audit.audit_log (
    log_id SERIAL PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    operation VARCHAR(10) NOT NULL,
    old_data JSONB,
    new_data JSONB,
    db_user VARCHAR(100) DEFAULT current_user,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
"

echo "========================================="
echo "3. Génération d'un million d'écritures"
echo "========================================="
sudo -u postgres psql -d novabank -c "
-- Création d'un client de test
INSERT INTO core.customers (first_name, last_name, email, birth_date)
VALUES ('Jean', 'Test', 'jean.test@novabank.fr', '1980-01-01');

-- Création d'un compte de test très bien approvisionné
INSERT INTO core.accounts (customer_id, iban, account_type, balance)
VALUES (1, 'FR7600000000000000000000001', 'COURANT', 10000000.00);

-- Injection ultra-rapide de 1 000 000 de transactions avec generate_series
INSERT INTO core.transactions (account_id, tx_type, amount, balance_after)
SELECT 
    1, 
    'CREDIT', 
    1.00, 
    10000000.00 + (g.id * 1.00)
FROM generate_series(1, 1000000) AS g(id);
"

echo "========================================="
echo "✅ Étape 2 terminée ! Base de données prête."
echo "========================================="
