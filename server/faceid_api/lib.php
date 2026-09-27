<?php
// Fonctions communes à api.php et admin.php.
declare(strict_types=1);

// Ne jamais afficher les erreurs PHP : elles peuvent contenir des mots de passe.
ini_set('display_errors', '0');
ini_set('zend.exception_ignore_args', '1');

require __DIR__ . '/config.php';

const PERSON_TYPES = ['eleve', 'enseignant', 'personnel', 'surveillant', 'autre'];
const PERSON_STATUSES = ['actif', 'parti', 'suspendu'];
const USER_STATUSES = ['pending', 'active', 'blocked'];
const PERMISSIONS = [
    'perm_scan' => 'Scanner / reconnaître',
    'perm_edit' => 'Ajouter et modifier des fiches',
    'perm_delete' => 'Supprimer des fiches',
    'perm_sensitive' => 'Voir les données sensibles (santé, parents)',
];
// Score minimal pour révéler l'identité d'une personne (même seuil que l'appli).
const MIN_SCORE = 0.48;

function db(): PDO
{
    static $pdo = null;
    if ($pdo === null) {
        try {
            $pdo = new PDO(
            'mysql:host=' . DB_HOST . ';port=' . DB_PORT . ';dbname=' . DB_NAME . ';charset=utf8mb4',
            DB_USER,
            DB_PASS,
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
            ]
            );
        } catch (PDOException $e) {
            // Message sans les identifiants (l'exception d'origine les contient).
            throw new RuntimeException(
                'Connexion à MySQL impossible (erreur ' . $e->getCode() . '). '
                . 'Vérifiez DB_HOST, DB_PORT, DB_USER et DB_PASS dans config.php.'
            );
        }
        ensure_schema($pdo);
    }
    return $pdo;
}

function ensure_schema(PDO $db): void
{
    // Tables de la première version (sans écoles) : données de test, supprimées.
    $db->exec('DROP TABLE IF EXISTS faceid_samples');
    $db->exec('DROP TABLE IF EXISTS faceid_persons');

    $db->exec("CREATE TABLE IF NOT EXISTS faceid_schools (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        city VARCHAR(255) NOT NULL DEFAULT '',
        active TINYINT(1) NOT NULL DEFAULT 1,
        created_at DATETIME NOT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $db->exec("CREATE TABLE IF NOT EXISTS faceid_users (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        school_id INT UNSIGNED NOT NULL,
        username VARCHAR(64) NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        full_name VARCHAR(255) NOT NULL,
        phone VARCHAR(50) NOT NULL DEFAULT '',
        role VARCHAR(16) NOT NULL DEFAULT 'agent',
        status VARCHAR(16) NOT NULL DEFAULT 'pending',
        perm_scan TINYINT(1) NOT NULL DEFAULT 1,
        perm_edit TINYINT(1) NOT NULL DEFAULT 0,
        perm_delete TINYINT(1) NOT NULL DEFAULT 0,
        perm_sensitive TINYINT(1) NOT NULL DEFAULT 0,
        created_at DATETIME NOT NULL,
        last_login_at DATETIME NULL,
        UNIQUE KEY uq_faceid_users_username (username),
        CONSTRAINT fk_faceid_users_school FOREIGN KEY (school_id)
            REFERENCES faceid_schools(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $db->exec("CREATE TABLE IF NOT EXISTS faceid_tokens (
        token_hash CHAR(64) NOT NULL PRIMARY KEY,
        user_id INT UNSIGNED NOT NULL,
        device_id VARCHAR(64) NOT NULL,
        created_at DATETIME NOT NULL,
        last_used_at DATETIME NOT NULL,
        CONSTRAINT fk_faceid_tokens_user FOREIGN KEY (user_id)
            REFERENCES faceid_users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $db->exec("CREATE TABLE IF NOT EXISTS faceid_login_fails (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        username VARCHAR(64) NOT NULL,
        at DATETIME NOT NULL,
        INDEX idx_faceid_login_fails (username, at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $db->exec("CREATE TABLE IF NOT EXISTS faceid_people (
        id CHAR(36) NOT NULL PRIMARY KEY,
        school_id INT UNSIGNED NOT NULL,
        type VARCHAR(16) NOT NULL,
        matricule VARCHAR(64) NOT NULL DEFAULT '',
        first_name VARCHAR(100) NOT NULL DEFAULT '',
        last_name VARCHAR(100) NOT NULL DEFAULT '',
        sex CHAR(1) NOT NULL DEFAULT '',
        birth_date DATE NULL,
        status VARCHAR(16) NOT NULL DEFAULT 'actif',
        class_level VARCHAR(100) NOT NULL DEFAULT '',
        school_year VARCHAR(20) NOT NULL DEFAULT '',
        enrollment_date DATE NULL,
        job_title VARCHAR(100) NOT NULL DEFAULT '',
        parent_name VARCHAR(255) NOT NULL DEFAULT '',
        parent_phone VARCHAR(50) NOT NULL DEFAULT '',
        address VARCHAR(500) NOT NULL DEFAULT '',
        medical TEXT NULL,
        notes TEXT NULL,
        photo MEDIUMBLOB NULL,
        created_by INT UNSIGNED NULL,
        created_at DATETIME NOT NULL,
        updated_at DATETIME NOT NULL,
        INDEX idx_faceid_people_school (school_id),
        CONSTRAINT fk_faceid_people_school FOREIGN KEY (school_id)
            REFERENCES faceid_schools(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $db->exec("CREATE TABLE IF NOT EXISTS faceid_embeddings (
        id CHAR(36) NOT NULL PRIMARY KEY,
        person_id CHAR(36) NOT NULL,
        school_id INT UNSIGNED NOT NULL,
        embedding BLOB NOT NULL,
        model VARCHAR(64) NOT NULL,
        INDEX idx_faceid_embeddings_school (school_id, model),
        CONSTRAINT fk_faceid_embeddings_person FOREIGN KEY (person_id)
            REFERENCES faceid_people(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}

function now(): string
{
    return date('Y-m-d H:i:s');
}

function str_len(string $v): int
{
    return function_exists('mb_strlen') ? mb_strlen($v, 'UTF-8') : strlen($v);
}

function is_uuid($v): bool
{
    return is_string($v)
        && preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i', $v) === 1;
}

function valid_username(string $u): bool
{
    return preg_match('/^[A-Za-z0-9._-]{3,64}$/', $u) === 1;
}

function hash_password(string $password): string
{
    return password_hash($password, PASSWORD_DEFAULT);
}

function h(?string $v): string
{
    return htmlspecialchars((string)$v, ENT_QUOTES, 'UTF-8');
}

class InputError extends Exception
{
}

/** Champs modifiables d'une fiche, validés. Lève InputError si invalide. */
function person_fields(array $src): array
{
    $text = function (string $key, int $max) use ($src): string {
        $v = $src[$key] ?? '';
        if ($v === null) $v = '';
        if (!is_string($v)) throw new InputError("Champ « $key » invalide.");
        $v = trim($v);
        if (str_len($v) > $max) throw new InputError("Champ « $key » trop long.");
        return $v;
    };
    $date = function (string $key) use ($text): ?string {
        $v = $text($key, 10);
        if ($v === '') return null;
        $d = DateTime::createFromFormat('!Y-m-d', $v);
        if ($d === false || $d->format('Y-m-d') !== $v) throw new InputError("Date « $key » invalide.");
        return $v;
    };
    $f = [
        'type' => $text('type', 16),
        'matricule' => $text('matricule', 64),
        'first_name' => $text('first_name', 100),
        'last_name' => $text('last_name', 100),
        'sex' => $text('sex', 1),
        'birth_date' => $date('birth_date'),
        'status' => $text('status', 16),
        'class_level' => $text('class_level', 100),
        'school_year' => $text('school_year', 20),
        'enrollment_date' => $date('enrollment_date'),
        'job_title' => $text('job_title', 100),
        'parent_name' => $text('parent_name', 255),
        'parent_phone' => $text('parent_phone', 50),
        'address' => $text('address', 500),
        'medical' => $text('medical', 5000),
        'notes' => $text('notes', 5000),
    ];
    if (!in_array($f['type'], PERSON_TYPES, true)) throw new InputError('Type de personne invalide.');
    if ($f['status'] === '') $f['status'] = 'actif';
    if (!in_array($f['status'], PERSON_STATUSES, true)) throw new InputError('Statut invalide.');
    if (!in_array($f['sex'], ['', 'M', 'F'], true)) throw new InputError('Sexe invalide.');
    if ($f['first_name'] === '' && $f['last_name'] === '') throw new InputError('Le nom est obligatoire.');
    return $f;
}
