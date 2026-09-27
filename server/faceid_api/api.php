<?php
// API JSON de FaceID École. Toutes les requêtes : POST {"action": ..., "api_key": ...}.
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
require __DIR__ . '/config.php';

const API_VERSION = 1;
const MAX_BODY = 4 * 1024 * 1024;
const MAX_PHOTO = 1024 * 1024;
const MAX_SAMPLES = 20;

function reply(array $data, int $code = 200): void
{
    http_response_code($code);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

function fail(string $message, int $code = 400): void
{
    reply(['ok' => false, 'error' => $message], $code);
}

set_exception_handler(function (Throwable $e): void {
    error_log('faceid_api: ' . $e);
    fail('Erreur interne du serveur.', 500);
});

function is_uuid($v): bool
{
    return is_string($v) && preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i', $v) === 1;
}

function text_field(array $src, string $key, int $max): string
{
    $v = $src[$key] ?? '';
    if (!is_string($v)) fail("Champ « $key » invalide.");
    $v = trim($v);
    if ((function_exists('mb_strlen') ? mb_strlen($v, 'UTF-8') : strlen($v)) > $max) fail("Champ « $key » trop long.");
    return $v;
}

function to_datetime($iso): string
{
    $t = is_string($iso) ? strtotime($iso) : false;
    return date('Y-m-d H:i:s', $t === false ? time() : $t);
}

/** Décode une empreinte envoyée en base64 (float32 little-endian). */
function decode_embedding($b64): string
{
    $bytes = is_string($b64) ? base64_decode($b64, true) : false;
    if ($bytes === false || strlen($bytes) === 0 || strlen($bytes) % 4 !== 0 || strlen($bytes) > 8192) {
        fail('Empreinte du visage invalide.');
    }
    return $bytes;
}

function cosine(array $a, array $b): float
{
    $n = count($a);
    if ($n !== count($b)) return -1.0;
    $dot = 0.0;
    $na = 0.0;
    $nb = 0.0;
    for ($i = 1; $i <= $n; $i++) {
        $x = $a[$i];
        $y = $b[$i];
        $dot += $x * $y;
        $na += $x * $x;
        $nb += $y * $y;
    }
    if ($na == 0.0 || $nb == 0.0) return 0.0;
    return $dot / (sqrt($na) * sqrt($nb));
}

function ensure_schema(PDO $db): void
{
    $db->exec("CREATE TABLE IF NOT EXISTS faceid_persons (
        id CHAR(36) NOT NULL PRIMARY KEY,
        device_id VARCHAR(64) NOT NULL,
        name VARCHAR(255) NOT NULL,
        role VARCHAR(255) NOT NULL DEFAULT '',
        description TEXT NOT NULL,
        photo MEDIUMBLOB NULL,
        created_at DATETIME NOT NULL,
        updated_at DATETIME NOT NULL,
        INDEX idx_faceid_persons_device (device_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    $db->exec("CREATE TABLE IF NOT EXISTS faceid_samples (
        id CHAR(36) NOT NULL PRIMARY KEY,
        person_id CHAR(36) NOT NULL,
        embedding BLOB NOT NULL,
        model VARCHAR(64) NOT NULL,
        INDEX idx_faceid_samples_model (model),
        CONSTRAINT fk_faceid_samples_person FOREIGN KEY (person_id)
            REFERENCES faceid_persons(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}

// ---------------------------------------------------------------- requête

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') fail('Utilisez POST.', 405);
$raw = file_get_contents('php://input', false, null, 0, MAX_BODY + 1);
if ($raw === false || strlen($raw) > MAX_BODY) fail('Requête trop volumineuse.', 413);
$req = json_decode($raw, true);
if (!is_array($req)) fail('JSON invalide.');
if (!is_string($req['api_key'] ?? null) || !hash_equals(API_KEY, $req['api_key'])) {
    fail("Code d'accès invalide.", 401);
}

$db = new PDO(
    'mysql:host=' . DB_HOST . ';port=' . DB_PORT . ';dbname=' . DB_NAME . ';charset=utf8mb4',
    DB_USER,
    DB_PASS,
    [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]
);
ensure_schema($db);

$deviceId = $req['device_id'] ?? '';
if (!is_uuid($deviceId)) fail('Identifiant d\'appareil invalide.');

switch ($req['action'] ?? '') {
    case 'ping':
        $count = (int)$db->query('SELECT COUNT(*) FROM faceid_persons')->fetchColumn();
        reply(['ok' => true, 'version' => API_VERSION, 'persons' => $count]);

    case 'upsert_person':
        $p = $req['person'] ?? null;
        if (!is_array($p) || !is_uuid($p['id'] ?? null)) fail('Personne invalide.');
        $name = text_field($p, 'name', 255);
        if ($name === '') fail('Le nom est obligatoire.');
        $role = text_field($p, 'role', 255);
        $description = text_field($p, 'description', 5000);

        $photo = null;
        if (isset($p['photo']) && $p['photo'] !== '') {
            $photo = is_string($p['photo']) ? base64_decode($p['photo'], true) : false;
            if ($photo === false || strlen($photo) > MAX_PHOTO) fail('Photo invalide.');
        }

        $samples = $req['samples'] ?? null;
        if (!is_array($samples) || count($samples) === 0 || count($samples) > MAX_SAMPLES) {
            fail('Empreintes du visage manquantes.');
        }
        $rows = [];
        foreach ($samples as $s) {
            if (!is_array($s) || !is_uuid($s['id'] ?? null)) fail('Empreinte invalide.');
            $model = text_field($s, 'model', 64);
            if ($model === '') fail('Modèle manquant.');
            $rows[] = [$s['id'], decode_embedding($s['embedding'] ?? null), $model];
        }

        $db->beginTransaction();
        $st = $db->prepare('SELECT device_id FROM faceid_persons WHERE id = ? FOR UPDATE');
        $st->execute([$p['id']]);
        $owner = $st->fetchColumn();
        if ($owner !== false && $owner !== $deviceId) {
            $db->rollBack();
            fail('Cette fiche appartient à un autre appareil.', 403);
        }
        if ($owner === false) {
            $st = $db->prepare('INSERT INTO faceid_persons
                (id, device_id, name, role, description, photo, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)');
            $st->execute([$p['id'], $deviceId, $name, $role, $description, $photo,
                to_datetime($p['created_at'] ?? null), to_datetime($p['updated_at'] ?? null)]);
        } else {
            $st = $db->prepare('UPDATE faceid_persons
                SET name = ?, role = ?, description = ?, photo = ?, updated_at = ? WHERE id = ?');
            $st->execute([$name, $role, $description, $photo,
                to_datetime($p['updated_at'] ?? null), $p['id']]);
        }
        $db->prepare('DELETE FROM faceid_samples WHERE person_id = ?')->execute([$p['id']]);
        $st = $db->prepare('INSERT INTO faceid_samples (id, person_id, embedding, model) VALUES (?, ?, ?, ?)');
        foreach ($rows as [$id, $embedding, $model]) {
            $st->bindValue(1, $id);
            $st->bindValue(2, $p['id']);
            $st->bindValue(3, $embedding, PDO::PARAM_LOB);
            $st->bindValue(4, $model);
            $st->execute();
        }
        $db->commit();
        reply(['ok' => true]);

    case 'delete_persons':
        $ids = $req['ids'] ?? null;
        if (!is_array($ids)) fail('Liste invalide.');
        // Un appareil ne peut supprimer que ses propres fiches.
        $st = $db->prepare('DELETE FROM faceid_persons WHERE id = ? AND device_id = ?');
        foreach ($ids as $id) {
            if (is_uuid($id)) $st->execute([$id, $deviceId]);
        }
        reply(['ok' => true]);

    case 'identify':
        $probe = unpack('g*', decode_embedding($req['embedding'] ?? null));
        $model = text_field($req, 'model', 64);
        $st = $db->prepare('SELECT person_id, embedding FROM faceid_samples WHERE model = ?');
        $st->execute([$model]);
        $bestId = null;
        $bestScore = -1.0;
        while ($row = $st->fetch()) {
            $score = cosine($probe, unpack('g*', $row['embedding']));
            if ($score > $bestScore) {
                $bestScore = $score;
                $bestId = $row['person_id'];
            }
        }
        if ($bestId === null) reply(['ok' => true, 'match' => null]);

        $st = $db->prepare('SELECT id, name, role, description, photo, created_at, updated_at
            FROM faceid_persons WHERE id = ?');
        $st->execute([$bestId]);
        $person = $st->fetch();
        if ($person === false) reply(['ok' => true, 'match' => null]);
        $person['photo'] = $person['photo'] === null ? null : base64_encode($person['photo']);
        $person['score'] = $bestScore;
        reply(['ok' => true, 'match' => $person]);

    default:
        fail('Action inconnue.');
}
