<?php
// Configuration du serveur FaceID École.
// ⚠️ Remplissez ces valeurs UNIQUEMENT sur le serveur, jamais dans le dépôt GitHub
// (le dépôt est public : tout le monde pourrait lire les mots de passe).

// Base MySQL créée dans le panneau de l'hébergeur (le nom de la base et de
// l'utilisateur ont souvent le préfixe du compte, par ex. "moncompte_faceid").
const DB_HOST = 'localhost';
const DB_PORT = 3306;
const DB_NAME = 'NOM_DE_LA_BASE';
const DB_USER = 'UTILISATEUR_MYSQL';
const DB_PASS = 'CHANGEZ_MOI';

// Super-administrateur de la page web admin.php (gère toutes les écoles).
// Il reste désactivé tant que le mot de passe commence par CHANGEZ_MOI.
const ADMIN_USER = 'superadmin';
const ADMIN_PASSWORD = 'CHANGEZ_MOI_AUSSI';
