<?php
// Configuration du serveur FaceID École.
// ⚠️ Remplissez ces valeurs UNIQUEMENT sur le serveur, jamais dans le dépôt GitHub
// (le dépôt est public : tout le monde pourrait lire les mots de passe).

// Si ce PHP tourne sur la même machine que MySQL, "127.0.0.1" suffit.
const DB_HOST = '127.0.0.1';
const DB_PORT = 3307;
const DB_NAME = 'abdou_base';
const DB_USER = 'abdou_user';
const DB_PASS = 'CHANGEZ_MOI';

// Super-administrateur de la page web admin.php (gère toutes les écoles).
// Il reste désactivé tant que le mot de passe commence par CHANGEZ_MOI.
const ADMIN_USER = 'superadmin';
const ADMIN_PASSWORD = 'CHANGEZ_MOI_AUSSI';
