#!/bin/bash
# 03_setup_roles.sh - Étape 3 : Création des profils et gestion des droits

set -e

echo "========================================="
echo "1. Création des rôles utilisateurs"
echo "========================================="
# La consigne dit "aucun mot de passe dans Git", on crée donc les rôles sans mots de passe en dur.
sudo -u postgres psql -d novabank -c "
-- On supprime les rôles s'ils existent déjà (pour pouvoir relancer le script)
DROP ROLE IF EXISTS appli;
DROP ROLE IF EXISTS analyste;
DROP ROLE IF EXISTS support;
DROP ROLE IF EXISTS auditeur;

-- Création des rôles (profils)
CREATE ROLE appli LOGIN;
CREATE ROLE analyste LOGIN;
CREATE ROLE support LOGIN;
CREATE ROLE auditeur LOGIN;
"

echo "========================================="
echo "2. Révocation des droits par défaut"
echo "========================================="
sudo -u postgres psql -d novabank -c "
-- Par sécurité, on interdit à tout le monde de créer des choses dans le schéma par défaut
REVOKE ALL ON SCHEMA public FROM PUBLIC;
"

echo "========================================="
echo "3. Attribution des droits stricts (GRANT)"
echo "========================================="
sudo -u postgres psql -d novabank -c "
--------------------------------------------------
-- PROFIL 1 : L'APPLICATION (appli)
-- Fait tourner le site web. A besoin d'écrire, mais pas de supprimer.
--------------------------------------------------
GRANT USAGE ON SCHEMA core, audit TO appli;

-- Peut lire, ajouter et modifier clients et comptes
GRANT SELECT, INSERT, UPDATE ON core.customers, core.accounts TO appli;

-- Ne peut QUE lire et ajouter des virements, écritures et alertes (JAMAIS d'UPDATE ni de DELETE)
GRANT SELECT, INSERT ON core.transfers, core.transactions, core.fraud_alerts TO appli;
GRANT SELECT, INSERT ON audit.audit_log TO appli;

-- Autorisation d'utiliser les compteurs automatiques (les ID)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA core TO appli;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA audit TO appli;

--------------------------------------------------
-- PROFIL 2 : L'ANALYSTE (analyste)
-- Fait des statistiques. Ne doit QUE lire.
--------------------------------------------------
GRANT USAGE ON SCHEMA core TO analyste;
GRANT SELECT ON ALL TABLES IN SCHEMA core TO analyste;

--------------------------------------------------
-- PROFIL 3 : LE SUPPORT CLIENT (support)
-- Aide les clients. Peut lire les infos, et modifier uniquement le téléphone/email.
--------------------------------------------------
GRANT USAGE ON SCHEMA core TO support;
GRANT SELECT ON ALL TABLES IN SCHEMA core TO support;
-- Droit ultra-ciblé : ne peut modifier QUE 2 colonnes précises
GRANT UPDATE (phone, email) ON core.customers TO support;

--------------------------------------------------
-- PROFIL 4 : L'AUDITEUR (auditeur)
-- Vérifie les fraudes et lit le journal d'audit.
--------------------------------------------------
GRANT USAGE ON SCHEMA core, audit TO auditeur;
GRANT SELECT ON ALL TABLES IN SCHEMA core TO auditeur;
GRANT SELECT ON ALL TABLES IN SCHEMA audit TO auditeur;
"

echo "========================================="
echo "✅ Étape 3 terminée ! Les 4 profils sont sécurisés."
echo "========================================="
