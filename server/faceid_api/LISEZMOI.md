# Serveur FaceID École (PHP + MySQL)

Ce dossier contient :
- `api.php` : l'API utilisée par l'application (comptes, fiches, reconnaissance) ;
- `admin.php` : la page web d'administration (écoles, comptes, élèves) ;
- `lib.php` : fonctions communes ;
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
