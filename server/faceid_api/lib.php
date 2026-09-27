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
                . 'Vérifiez DB_HOST, DB_PORT, DB_USER et DB_PASS dans ' . __DIR__ . DIRECTORY_SEPARATOR
                . 'config.php. Ce fichier contient actuellement : serveur ' . DB_HOST . ':' . DB_PORT
                . ', mot de passe ' . (strpos(DB_PASS, 'CHANGEZ_MOI') === 0
                    ? 'NON REMPLI (encore CHANGEZ_MOI).'
                    : 'rempli (' . strlen(DB_PASS) . ' caractères).')
            );
        }
        ensure_schema($pdo);
    }
    return $pdo;
}

const SCHEMA_VERSION = 2;

/** Crée ou met à jour les tables ; ne fait rien si elles sont à jour. */
function ensure_schema(PDO $db): void
{
    $db->exec('CREATE TABLE IF NOT EXISTS faceid_meta (
        name VARCHAR(32) NOT NULL PRIMARY KEY,
        value VARCHAR(255) NOT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4');
    $version = (int)$db->query("SELECT value FROM faceid_meta WHERE name = 'schema'")->fetchColumn();
    if ($version >= SCHEMA_VERSION) return;

    if ($version < 1) create_tables($db);
    if ($version < 2) {
        // Liaison avec le système de gestion de l'école.
        add_column($db, 'faceid_schools', "mgmt_enabled TINYINT(1) NOT NULL DEFAULT 0");
        add_column($db, 'faceid_schools', "mgmt_url VARCHAR(500) NOT NULL DEFAULT ''");
        add_column($db, 'faceid_schools', "mgmt_key VARCHAR(255) NOT NULL DEFAULT ''");
        add_column($db, 'faceid_schools', "mgmt_record_url VARCHAR(500) NOT NULL DEFAULT ''");
    }
    $db->prepare("REPLACE INTO faceid_meta (name, value) VALUES ('schema', ?)")
        ->execute([(string)SCHEMA_VERSION]);
}

function add_column(PDO $db, string $table, string $definition): void
{
    try {
        $db->exec("ALTER TABLE $table ADD COLUMN $definition");
    } catch (PDOException $e) {
        // 1060 : colonne déjà présente (mise à jour lancée deux fois).
        if ((int)($e->errorInfo[1] ?? 0) !== 1060) throw $e;
    }
}

function create_tables(PDO $db): void
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

// ---------------------------------------------------------------- système de gestion

/** Champs qu'un système de gestion peut renvoyer (contrat FaceID, cf. LISEZMOI). */
const MGMT_FIELDS = [
    'type' => 16, 'matricule' => 64, 'first_name' => 100, 'last_name' => 100, 'sex' => 1,
    'birth_date' => 10, 'status' => 16, 'class_level' => 100, 'school_year' => 20,
    'enrollment_date' => 10, 'job_title' => 100, 'parent_name' => 255, 'parent_phone' => 50,
    'address' => 500, 'medical' => 5000, 'notes' => 5000,
];
const SENSITIVE_FIELDS = ['birth_date', 'parent_name', 'parent_phone', 'address', 'medical'];

function is_http_url(string $url): bool
{
    return preg_match('#^https?://[^\s]+$#i', $url) === 1;
}

/** Adresse de la fiche dans le système de gestion ({matricule} est remplacé). */
function mgmt_record_url(array $school, string $matricule): string
{
    $tpl = (string)($school['mgmt_record_url'] ?? '');
    if ($tpl === '' || $matricule === '') return '';
    return str_replace('{matricule}', rawurlencode($matricule), $tpl);
}

/**
 * Cherche un élève par matricule dans le système de gestion de l'école.
 * Renvoie ['found' => bool, 'fields' => [...], 'record_url' => string].
 * Lève RuntimeException si le système est injoignable ou répond mal.
 */
function mgmt_lookup(array $school, string $matricule): array
{
    $url = (string)$school['mgmt_url'];
    if (!is_http_url($url)) throw new RuntimeException("Adresse du système de gestion invalide.");
    $url .= (strpos($url, '?') === false ? '?' : '&') . 'matricule=' . rawurlencode($matricule);
    $headers = ['Accept: application/json', 'X-FaceID-Key: ' . $school['mgmt_key']];

    if (function_exists('curl_init')) {
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER => $headers,
            CURLOPT_CONNECTTIMEOUT => 5,
            CURLOPT_TIMEOUT => 10,
            CURLOPT_FOLLOWLOCATION => false,
        ]);
        $body = curl_exec($ch);
        $code = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $err = curl_error($ch);
        curl_close($ch);
        if ($body === false) throw new RuntimeException("Système de gestion injoignable ($err).");
    } else {
        $ctx = stream_context_create(['http' => [
            'method' => 'GET', 'header' => implode("\r\n", $headers),
            'timeout' => 10, 'ignore_errors' => true, 'follow_location' => 0,
        ]]);
        $body = @file_get_contents($url, false, $ctx);
        if ($body === false) throw new RuntimeException('Système de gestion injoignable.');
        $code = 200;
        foreach ($http_response_header ?? [] as $h) {
            if (preg_match('#^HTTP/\S+\s+(\d+)#', $h, $m)) $code = (int)$m[1];
        }
    }

    $data = json_decode((string)$body, true);
    if (!is_array($data)) {
        throw new RuntimeException("Réponse invalide du système de gestion (HTTP $code).");
    }
    if (($data['ok'] ?? false) !== true) {
        $msg = is_string($data['error'] ?? null) ? $data['error'] : "erreur HTTP $code";
        throw new RuntimeException('Système de gestion : ' . substr($msg, 0, 200));
    }
    $student = $data['student'] ?? null;
    if (($data['found'] ?? false) !== true || !is_array($student)) {
        return ['found' => false, 'fields' => [], 'record_url' => ''];
    }

    // On ne garde que les champs connus et valides ; les autres sont ignorés.
    $fields = [];
    foreach (MGMT_FIELDS as $key => $max) {
        $v = $student[$key] ?? null;
        if (!is_string($v) && !is_int($v)) continue;
        $v = trim((string)$v);
        if ($v === '' || str_len($v) > $max) continue;
        if (($key === 'birth_date' || $key === 'enrollment_date')) {
            $d = DateTime::createFromFormat('!Y-m-d', $v);
            if ($d === false || $d->format('Y-m-d') !== $v) continue;
        }
        if ($key === 'sex') {
            $v = strtoupper($v);
            if (!in_array($v, ['M', 'F'], true)) continue;
        }
        if ($key === 'type' && !in_array($v, PERSON_TYPES, true)) continue;
        if ($key === 'status' && !in_array($v, PERSON_STATUSES, true)) continue;
        $fields[$key] = $v;
    }
    $record = is_string($student['record_url'] ?? null) && is_http_url($student['record_url'])
        ? $student['record_url']
        : mgmt_record_url($school, $fields['matricule'] ?? $matricule);
    return ['found' => true, 'fields' => $fields, 'record_url' => $record];
}
