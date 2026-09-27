# Serveur FaceID École (PHP + MySQL)

Ce dossier contient :
- `api.php` : l'API utilisée par l'application (comptes, fiches, reconnaissance) ;
- `admin.php` : la page web d'administration (écoles, comptes, élèves) ;
- `lib.php` : fonctions communes ;
- `demo_gestion.php` : simulateur de système de gestion d'école, pour les tests
  (à supprimer ensuite) ;
- `config.php` : vos réglages (mots de passe) ;
- `.htaccess` : bloque l'accès direct à `config.php`, `lib.php` et ce fichier.

## Installation / mise à jour

1. Copiez tous les fichiers du dossier sur le serveur, à la même place qu'avant
   (par ex. `dolibarr/faceid_api`). Remplacez les anciens fichiers.
2. Ouvrez `config.php` **sur le serveur** et remplissez :
   - `DB_PASS` : le mot de passe MySQL ;
   - `ADMIN_PASSWORD` : le mot de passe du super-administrateur de la page web
     (identifiant : `ADMIN_USER`, par défaut `superadmin`).

   ⚠️ Ne mettez jamais ces mots de passe dans GitHub : le dépôt est public.
3. Les tables sont créées automatiquement. Les anciennes tables de test
   (`faceid_persons`, `faceid_samples`) sont supprimées.

## Utilisation

1. Ouvrez `http://102.214.210.18:81/dolibarr/faceid_api/admin.php` et
   connectez-vous en super-administrateur.
2. Créez une école, puis, dans l'école, un compte **Administrateur de l'école**
   (le directeur). Il pourra se connecter à la même page web et ne verra que
   son école.
3. Les agents créent leur compte dans l'application (« Créer un compte ») en
   choisissant leur école. Le compte apparaît « En attente » sur la page web.
4. L'administrateur clique **Autoriser** et coche les permissions :
   - Scanner / reconnaître ;
   - Ajouter et modifier des fiches ;
   - Supprimer des fiches ;
   - Voir les données sensibles (santé, parents).
5. **Bloquer** déconnecte immédiatement le téléphone de l'agent.

L'onglet « Élèves et personnel » permet de voir, modifier et supprimer les
fiches. L'ajout se fait dans l'application, car il faut enregistrer le visage.

## Liaison avec le système de gestion de l'école (facultatif)

Chaque école peut avoir son propre système de gestion (base et adresse
différentes). Dans la page web, fiche de l'école, section « Système de
gestion de l'école » :

- **Adresse de l'API** : l'adresse qui répond au contrat ci-dessous ;
- **Adresse d'une fiche élève** : lien ouvert depuis l'application après la
  reconnaissance ; `{matricule}` y est remplacé par le matricule ;
- **Clé d'accès** : envoyée au système de gestion ; elle reste sur le serveur
  FaceID, jamais sur les téléphones ;
- **Activer la liaison**, puis **Tester la recherche** avec un matricule.

Une fois activée, l'agent tape le matricule dans l'application et appuie sur
🔍 : les champs connus du système de gestion sont remplis (ils remplacent ce
qui était saisi), les autres restent tels quels.

### Contrat système de gestion

Le serveur FaceID appelle :

```
GET <adresse de l'API>?matricule=E001
X-FaceID-Key: <clé d'accès>
```

Réponses attendues (JSON, UTF-8) :

```json
{"ok": true, "found": true, "student": {
  "matricule": "E001", "first_name": "Amina", "last_name": "Sow",
  "type": "eleve", "sex": "F", "birth_date": "2013-04-12", "status": "actif",
  "class_level": "6e A", "school_year": "2026-2027", "enrollment_date": "2024-09-15",
  "job_title": "", "parent_name": "Moussa Sow", "parent_phone": "+222 …",
  "address": "…", "medical": "…", "notes": "…",
  "record_url": "https://…/fiche?id=12"
}}
{"ok": true, "found": false}
{"ok": false, "error": "Clé invalide"}
```

Tous les champs de `student` sont facultatifs ; un champ absent, vide ou
invalide est ignoré. Valeurs possibles :
- `type` : `eleve`, `enseignant`, `personnel`, `surveillant`, `autre` ;
- `sex` : `M` ou `F` ;
- `status` : `actif`, `parti`, `suspendu` ;
- dates au format `AAAA-MM-JJ` ;
- `record_url` (facultatif) remplace l'« adresse d'une fiche élève ».

### Tester avec le simulateur

Dans la fiche d'une école de test :
- Adresse de l'API : `http://127.0.0.1:81/dolibarr/faceid_api/demo_gestion.php`
  (le serveur s'appelle lui-même : utilisez `127.0.0.1`) ;
- Adresse d'une fiche : `http://102.214.210.18:81/dolibarr/faceid_api/demo_gestion.php?fiche={matricule}`
  (ouverte par le téléphone : utilisez l'adresse publique) ;
- Clé : `demo-faceid` ;
- Matricules de test : `E001`, `E002`, `E003`, `P001`.

## Sécurité

- Les mots de passe des comptes sont chiffrés (`password_hash`).
- Chaque école ne voit que ses propres fiches, y compris pendant la
  reconnaissance.
- Nom et photo ne sont renvoyés que si la ressemblance est suffisante.
- 8 mauvais mots de passe en 15 minutes bloquent temporairement la connexion.
- Il est conseillé de fermer le port MySQL (3307) à Internet et de passer en
  HTTPS si possible.

## Prérequis

PHP 7.3 ou plus récent avec l’extension `pdo_mysql`, MySQL 5.7+ ou MariaDB 10.2+.
