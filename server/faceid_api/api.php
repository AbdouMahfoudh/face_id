<?php
// API JSON de FaceID École. Toutes les requêtes : POST {"action": ..., ...}.
// Les actions autres que schools/register/login exigent "token" (obtenu au login).
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
require __DIR__ . '/lib.php';

const API_VERSION = 2;
const MAX_BODY = 4 * 1024 * 1024;
const MAX_PHOTO = 1024 * 1024;
const MAX_SAMPLES = 20;
const MAX_LOGIN_FAILS = 8; // par identifiant, sur 15 minutes

function reply(array $data, int $code = 200): void
{
    http_response_code($code);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

function fail(string $message, int $code = 400, string $reason = ''): void
{
    $body = ['ok' => false, 'error' => $message];
    if ($reason !== '') $body['reason'] = $reason;
    reply($body, $code);
}

set_exception_handler(function (Throwable $e): void {
    if ($e instanceof InputError) fail($e->getMessage());
    error_log('faceid_api: ' . $e->getMessage());
    fail($e instanceof RuntimeException ? $e->getMessage() : 'Erreur interne du serveur.', 500);
});

function text_field(array $src, string $key, int $max): string
{
    $v = $src[$key] ?? '';
    if (!is_string($v)) fail("Champ « $key » invalide.");
    $v = trim($v);
    if (str_len($v) > $max) fail("Champ « $key » trop long.");
    return $v;
}

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

function to_datetime($iso): string
{
    $t = is_string($iso) ? strtotime($iso) : false;
    return date('Y-m-d H:i:s', $t === false ? time() : $t);
}

function user_json(array $u): array
{
    return [
        'id' => (int)$u['id'],
        'username' => $u['username'],
        'full_name' => $u['full_name'],
        'role' => $u['role'],
        'school' => ['id' => (int)$u['school_id'], 'name' => $u['school_name']],
        'permissions' => [
            'scan' => (bool)$u['perm_scan'],
            'edit' => (bool)$u['perm_edit'],
            'delete' => (bool)$u['perm_delete'],
            'sensitive' => (bool)$u['perm_sensitive'],
        ],
    ];
}

function status_error(string $status): void
{
    if ($status === 'pending') {
        fail("Votre compte est en attente de validation par l'administrateur.", 403, 'pending');
    }
    if ($status !== 'active') fail("Votre compte est bloqué. Contactez l'administrateur.", 403, 'blocked');
}

const USER_SELECT = 'SELECT u.*, s.name AS school_name, s.active AS school_active
    FROM faceid_users u JOIN faceid_schools s ON s.id = u.school_id';

/** Utilisateur connecté (via son jeton), actif et dans une école active. */
function current_user(PDO $db, array $req): array
{
    $token = $req['token'] ?? '';
    if (!is_string($token) || strlen($token) !== 64) fail('Session expirée, reconnectez-vous.', 401, 'session');
    $hash = hash('sha256', $token);
    $st = $db->prepare(USER_SELECT . ' JOIN faceid_tokens t ON t.user_id = u.id WHERE t.token_hash = ?');
    $st->execute([$hash]);
    $u = $st->fetch();
    if ($u === false) fail('Session expirée, reconnectez-vous.', 401, 'session');
    if (!(int)$u['school_active']) fail("Cette école est désactivée.", 403, 'blocked');
    status_error($u['status']);
    $db->prepare('UPDATE faceid_tokens SET last_used_at = ? WHERE token_hash = ?')->execute([now(), $hash]);
    return $u;
}

function require_perm(array $u, string $perm): void
{
    if ($u['role'] !== 'admin' && !(int)$u[$perm]) {
        fail("Vous n'avez pas la permission pour cette action.", 403, 'permission');
    }
}

// ---------------------------------------------------------------- requête

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') fail('Utilisez POST.', 405);
$raw = file_get_contents('php://input', false, null, 0, MAX_BODY + 1);
if ($raw === false || strlen($raw) > MAX_BODY) fail('Requête trop volumineuse.', 413);
$req = json_decode($raw, true);
if (!is_array($req)) fail('JSON invalide.');

$db = db();

switch ($req['action'] ?? '') {
    case 'ping':
        reply(['ok' => true, 'version' => API_VERSION]);

    case 'schools':
        $rows = $db->query('SELECT id, name, city FROM faceid_schools WHERE active = 1 ORDER BY name')->fetchAll();
        foreach ($rows as &$r) $r['id'] = (int)$r['id'];
        reply(['ok' => true, 'schools' => $rows]);

    case 'register':
        $schoolId = (int)($req['school_id'] ?? 0);
        $username = text_field($req, 'username', 64);
        $fullName = text_field($req, 'full_name', 255);
        $phone = text_field($req, 'phone', 50);
        $password = $req['password'] ?? '';
        if (!valid_username($username)) {
            fail("Identifiant invalide : 3 caractères minimum, lettres, chiffres, point, tiret.");
        }
        if ($fullName === '') fail('Le nom complet est obligatoire.');
        if (!is_string($password) || strlen($password) < 6 || strlen($password) > 200) {
            fail('Le mot de passe doit contenir au moins 6 caractères.');
        }
        $st = $db->prepare('SELECT id FROM faceid_schools WHERE id = ? AND active = 1');
        $st->execute([$schoolId]);
        if ($st->fetchColumn() === false) fail('École introuvable.');
        $st = $db->prepare('SELECT 1 FROM faceid_users WHERE username = ?');
        $st->execute([$username]);
        if ($st->fetchColumn() !== false) fail('Cet identifiant est déjà utilisé.');
        $db->prepare("INSERT INTO faceid_users
            (school_id, username, password_hash, full_name, phone, role, status,
             perm_scan, perm_edit, perm_delete, perm_sensitive, created_at)
            VALUES (?, ?, ?, ?, ?, 'agent', 'pending', 1, 0, 0, 0, ?)")
            ->execute([$schoolId, $username, hash_password($password), $fullName, $phone, now()]);
        reply(['ok' => true]);

    case 'login':
        $username = text_field($req, 'username', 64);
        $password = $req['password'] ?? '';
        $deviceId = $req['device_id'] ?? '';
        if (!is_uuid($deviceId)) fail("Identifiant d'appareil invalide.");
        $db->prepare('DELETE FROM faceid_login_fails WHERE at < ?')
            ->execute([date('Y-m-d H:i:s', time() - 15 * 60)]);
        $st = $db->prepare('SELECT COUNT(*) FROM faceid_login_fails WHERE username = ?');
        $st->execute([$username]);
        if ((int)$st->fetchColumn() >= MAX_LOGIN_FAILS) {
            fail('Trop de tentatives. Réessayez dans 15 minutes.', 429);
        }
        $st = $db->prepare(USER_SELECT . ' WHERE u.username = ?');
        $st->execute([$username]);
        $u = $st->fetch();
        if ($u === false || !is_string($password) || !password_verify($password, $u['password_hash'])) {
            $db->prepare('INSERT INTO faceid_login_fails (username, at) VALUES (?, ?)')->execute([$username, now()]);
            fail('Identifiant ou mot de passe incorrect.', 401);
        }
        if (!(int)$u['school_active']) fail("Cette école est désactivée.", 403, 'blocked');
        status_error($u['status']);
        $token = bin2hex(random_bytes(32));
        $db->prepare('INSERT INTO faceid_tokens (token_hash, user_id, device_id, created_at, last_used_at)
            VALUES (?, ?, ?, ?, ?)')->execute([hash('sha256', $token), $u['id'], $deviceId, now(), now()]);
        $db->prepare('UPDATE faceid_users SET last_login_at = ? WHERE id = ?')->execute([now(), $u['id']]);
        reply(['ok' => true, 'token' => $token, 'user' => user_json($u)]);

    case 'logout':
        $token = $req['token'] ?? '';
        if (is_string($token)) {
            $db->prepare('DELETE FROM faceid_tokens WHERE token_hash = ?')->execute([hash('sha256', $token)]);
        }
        reply(['ok' => true]);

    case 'me':
        reply(['ok' => true, 'user' => user_json(current_user($db, $req))]);

    case 'upsert_person':
        $u = current_user($db, $req);
        require_perm($u, 'perm_edit');
        $schoolId = (int)$u['school_id'];
        $p = $req['person'] ?? null;
        if (!is_array($p) || !is_uuid($p['id'] ?? null)) fail('Personne invalide.');
        $fields = person_fields($p);

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
        $st = $db->prepare('SELECT school_id FROM faceid_people WHERE id = ? FOR UPDATE');
        $st->execute([$p['id']]);
        $owner = $st->fetchColumn();
        if ($owner !== false && (int)$owner !== $schoolId) {
            $db->rollBack();
            fail('Cette fiche appartient à une autre école.', 403, 'permission');
        }
        $cols = array_keys($fields);
        if ($owner === false) {
            $all = array_merge(['id', 'school_id'], $cols, ['photo', 'created_by', 'created_at', 'updated_at']);
            $st = $db->prepare('INSERT INTO faceid_people (' . implode(', ', $all) . ') VALUES ('
                . implode(', ', array_fill(0, count($all), '?')) . ')');
            $st->execute(array_merge([$p['id'], $schoolId], array_values($fields), [
                $photo, $u['id'], to_datetime($p['created_at'] ?? null), to_datetime($p['updated_at'] ?? null),
            ]));
        } else {
            $set = implode(', ', array_map(function ($c) { return "$c = ?"; }, $cols));
            $st = $db->prepare("UPDATE faceid_people SET $set, photo = ?, updated_at = ? WHERE id = ?");
            $st->execute(array_merge(array_values($fields), [
                $photo, to_datetime($p['updated_at'] ?? null), $p['id'],
            ]));
        }
        $db->prepare('DELETE FROM faceid_embeddings WHERE person_id = ?')->execute([$p['id']]);
        $st = $db->prepare('INSERT INTO faceid_embeddings (id, person_id, school_id, embedding, model)
            VALUES (?, ?, ?, ?, ?)');
        foreach ($rows as [$id, $embedding, $model]) {
            $st->bindValue(1, $id);
            $st->bindValue(2, $p['id']);
            $st->bindValue(3, $schoolId, PDO::PARAM_INT);
            $st->bindValue(4, $embedding, PDO::PARAM_LOB);
            $st->bindValue(5, $model);
            $st->execute();
        }
        $db->commit();
        reply(['ok' => true]);

    case 'delete_persons':
        $u = current_user($db, $req);
        require_perm($u, 'perm_delete');
        $ids = $req['ids'] ?? null;
        if (!is_array($ids)) fail('Liste invalide.');
        $st = $db->prepare('DELETE FROM faceid_people WHERE id = ? AND school_id = ?');
        foreach ($ids as $id) {
            if (is_uuid($id)) $st->execute([$id, $u['school_id']]);
        }
        reply(['ok' => true]);

    case 'identify':
        $u = current_user($db, $req);
        require_perm($u, 'perm_scan');
        $probe = unpack('g*', decode_embedding($req['embedding'] ?? null));
        $model = text_field($req, 'model', 64);
        $st = $db->prepare('SELECT person_id, embedding FROM faceid_embeddings WHERE school_id = ? AND model = ?');
        $st->execute([$u['school_id'], $model]);
        $bestId = null;
        $bestScore = -1.0;
        while ($row = $st->fetch()) {
            $score = cosine($probe, unpack('g*', $row['embedding']));
            if ($score > $bestScore) {
                $bestScore = $score;
                $bestId = $row['person_id'];
            }
        }
        // En dessous du seuil, on ne révèle ni nom ni photo.
        if ($bestId === null || $bestScore < MIN_SCORE) {
            reply(['ok' => true, 'match' => null, 'score' => max(0.0, $bestScore)]);
        }
        $st = $db->prepare('SELECT * FROM faceid_people WHERE id = ? AND school_id = ?');
        $st->execute([$bestId, $u['school_id']]);
        $person = $st->fetch();
        if ($person === false) reply(['ok' => true, 'match' => null, 'score' => 0]);
        unset($person['school_id'], $person['created_by']);
        if ($u['role'] !== 'admin' && !(int)$u['perm_sensitive']) {
            foreach (['birth_date', 'parent_name', 'parent_phone', 'address', 'medical'] as $k) {
                $person[$k] = null;
            }
        }
        $person['photo'] = $person['photo'] === null ? null : base64_encode($person['photo']);
        $person['score'] = $bestScore;
        reply(['ok' => true, 'match' => $person]);

    default:
        fail('Action inconnue.');
}
