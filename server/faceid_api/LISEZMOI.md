# Serveur FaceID École (PHP + MySQL)

Ce dossier permet à l'application de :
- envoyer les personnes enregistrées sur chaque téléphone vers la base en ligne ;
- comparer un visage scanné avec **toute** la base en ligne quand Internet est disponible.

Le téléphone calcule l'« empreinte » du visage (192 nombres). Le PHP compare
seulement ces nombres : aucune bibliothèque spéciale n'est nécessaire.

## Installation

1. Copiez le dossier `faceid_api` sur votre serveur web, par exemple dans
   `htdocs/faceid_api` (XAMPP) ou `/var/www/html/faceid_api` (Apache).
2. Ouvrez `config.php` **sur le serveur** et remplissez :
   - `DB_HOST` : `127.0.0.1` si MySQL est sur la même machine que PHP ;
   - `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASS` : vos identifiants MySQL ;
   - `API_KEY` : un code secret long que vous choisissez.

   ⚠️ Ne mettez jamais le vrai mot de passe dans GitHub : le dépôt est public.
3. Les tables `faceid_persons` et `faceid_samples` sont créées automatiquement
   au premier appel.
4. Dans l'application : **Réglages** (icône en haut à droite de l'accueil)
   - Adresse du serveur : `http://102.214.210.18/faceid_api`
   - Code d'accès : la valeur de `API_KEY`
   - Appuyez sur **Enregistrer et tester**.

## Vérifier depuis un navigateur

Ouvrir `http://102.214.210.18/faceid_api/api.php` doit afficher :

```json
{"ok":false,"error":"Utilisez POST."}
```

Cela prouve que PHP fonctionne. Si le navigateur télécharge le fichier ou
affiche le code source, PHP n'est pas activé sur ce dossier.

## Sécurité

- Le mot de passe MySQL reste sur le serveur ; l'application ne le connaît pas.
- Chaque téléphone ne peut modifier ou supprimer que les fiches qu'il a créées.
- Le fichier `.htaccess` (Apache) bloque l'accès direct à `config.php`.
  Avec Nginx, ajoutez une règle équivalente.
- Il est conseillé de fermer le port MySQL (3307) à Internet et de passer en
  HTTPS si possible.

## Prérequis

PHP 7.1 ou plus récent avec l’extension `pdo_mysql`, MySQL 5.7+ ou MariaDB 10.2+.
