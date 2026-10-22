Projet NovaBank - Base de données

Voici mon projet de BDD pour NovaBank (PostgreSQL sur une VM Ubuntu). L'objectif est de sécuriser et optimiser l'ancienne base avec 3 axes :
1. **Sécurité :** Gestion stricte des rôles (Analyste, Support, Appli, Auditeur).
2. **Fiabilité :** Virements sécurisés (transactions ACID) et historique bloqué (Triggers).
3. **Performances :** Injection d'1 million de lignes et création d'Index pour des requêtes instantanées.

Zéro mot de passe en dur dans le code (on utilise l'auth `peer`). Pour tout remonter sur une VM vierge, lancez juste ces scripts dans l'ordre :

1. `./01_install_server.sh` : Installe PostgreSQL et gère la config (UFW, pg_hba).
2. `./02_setup_database.sh` : Crée la base, les tables et injecte le million de lignes.
3. `./03_setup_roles.sh` : Met en place les droits d'accès.
4. `./04_setup_views.sh` : Crée les vues (sécurisées et matérialisées).
5. `./05_setup_indexes.sh` : Ajoute les index pour booster la vitesse.
6. `./06_setup_triggers.sh` : Automatise les calculs, l'audit et la détection de fraude.
7. `./07_setup_procedures.sh` : Ajoute les procédures stockées (le virement).
8. `./08_tests_and_backup.sh` : Teste les sécurités et génère la sauvegarde `.sql`.
