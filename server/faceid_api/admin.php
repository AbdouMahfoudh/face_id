<?php
// Interface web d'administration de FaceID École.
// - Super-administrateur (identifiants de config.php) : toutes les écoles.
// - Administrateur d'école (compte "admin" créé ici) : uniquement son école.
declare(strict_types=1);

require __DIR__ . '/lib.php';

set_exception_handler(function (Throwable $e): void {
    error_log('faceid_admin: ' . $e->getMessage());
    http_response_code(500);
    $msg = $e instanceof RuntimeException ? $e->getMessage() : 'Erreur interne du serveur.';
    echo '<!doctype html><meta charset="utf-8"><title>Erreur</title>'
        . '<div style="font-family:system-ui;max-width:640px;margin:60px auto;padding:20px;'
        . 'border-radius:14px;background:#FDECEC;color:#8E1F1F">'
        . '<h2 style="margin-top:0">FaceID École — erreur</h2><p>' . h($msg) . '</p></div>';
});

session_name('faceid_admin');
session_set_cookie_params(['httponly' => true, 'samesite' => 'Strict']);
session_start();
header('X-Frame-Options: DENY');

$db = db();
$flash = null;
$error = null;

// ------------------------------------------------------------ utilitaires

function csrf(): string
{
    if (empty($_SESSION['csrf'])) $_SESSION['csrf'] = bin2hex(random_bytes(16));
    return $_SESSION['csrf'];
}

function csrf_field(): string
{
    return '<input type="hidden" name="csrf" value="' . csrf() . '">';
}

function go(string $query, string $flash = ''): void
{
    if ($flash !== '') $_SESSION['flash'] = $flash;
    header('Location: admin.php' . ($query === '' ? '' : '?' . $query));
    exit;
}

function is_super(): bool
{
    return ($_SESSION['who']['super'] ?? false) === true;
}

/** École autorisée pour l'utilisateur connecté, ou arrêt. */
function allowed_school(PDO $db, int $id): array
{
    if (!is_super() && $id !== (int)($_SESSION['who']['school_id'] ?? -1)) {
        http_response_code(403);
        exit('Accès refusé.');
    }
    $st = $db->prepare('SELECT * FROM faceid_schools WHERE id = ?');
    $st->execute([$id]);
    $s = $st->fetch();
    if ($s === false) go('', 'École introuvable.');
    return $s;
}

function load_user(PDO $db, int $id): array
{
    $st = $db->prepare('SELECT * FROM faceid_users WHERE id = ?');
    $st->execute([$id]);
    $u = $st->fetch();
    if ($u === false) go('', 'Compte introuvable.');
    allowed_school($db, (int)$u['school_id']);
    return $u;
}

function load_person(PDO $db, string $id): array
{
    $st = $db->prepare('SELECT * FROM faceid_people WHERE id = ?');
    $st->execute([$id]);
    $p = $st->fetch();
    if ($p === false) go('', 'Fiche introuvable.');
    allowed_school($db, (int)$p['school_id']);
    return $p;
}

function person_name(array $p): string
{
    return trim($p['first_name'] . ' ' . $p['last_name']);
}

const TYPE_LABELS = [
    'eleve' => 'Élève', 'enseignant' => 'Enseignant', 'personnel' => 'Personnel',
    'surveillant' => 'Surveillant', 'autre' => 'Autre',
];
const STATUS_LABELS = ['pending' => 'En attente', 'active' => 'Autorisé', 'blocked' => 'Bloqué'];
const PERSON_STATUS_LABELS = ['actif' => 'Actif', 'parti' => 'Parti', 'suspendu' => 'Suspendu'];

$page = $_GET['page'] ?? '';
$defaultPassword = strpos(ADMIN_PASSWORD, 'CHANGEZ_MOI') === 0;

// ------------------------------------------------------------ photo

if ($page === 'photo' && isset($_SESSION['who'])) {
    $p = load_person($db, (string)($_GET['id'] ?? ''));
    if ($p['photo'] === null) {
        http_response_code(404);
        exit;
    }
    header('Content-Type: image/jpeg');
    header('Cache-Control: private, max-age=300');
    echo $p['photo'];
    exit;
}

// ------------------------------------------------------------ actions (POST)

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $a = $_POST['action'] ?? '';
    if ($a !== 'login' && !hash_equals(csrf(), (string)($_POST['csrf'] ?? ''))) {
        go('', 'Session expirée, recommencez.');
    }
    try {
        switch ($a) {
            case 'login':
                $user = trim((string)($_POST['username'] ?? ''));
                $pass = (string)($_POST['password'] ?? '');
                usleep(300000);
                if (!$defaultPassword && hash_equals(ADMIN_USER, $user) && hash_equals(ADMIN_PASSWORD, $pass)) {
                    session_regenerate_id(true);
                    $_SESSION['who'] = ['super' => true, 'name' => 'Super-administrateur'];
                    go('');
                }
                $st = $db->prepare("SELECT u.*, s.active AS school_active FROM faceid_users u
                    JOIN faceid_schools s ON s.id = u.school_id WHERE u.username = ? AND u.role = 'admin'");
                $st->execute([$user]);
                $u = $st->fetch();
                if ($u !== false && password_verify($pass, $u['password_hash'])
                    && $u['status'] === 'active' && (int)$u['school_active']) {
                    session_regenerate_id(true);
                    $_SESSION['who'] = [
                        'super' => false, 'id' => (int)$u['id'],
                        'school_id' => (int)$u['school_id'], 'name' => $u['full_name'],
                    ];
                    go('page=school&id=' . $u['school_id']);
                }
                $error = 'Identifiant ou mot de passe incorrect.';
                break;

            case 'logout':
                $_SESSION = [];
                session_destroy();
                go('');

            case 'school_save':
                $id = (int)($_POST['id'] ?? 0);
                $name = trim((string)($_POST['name'] ?? ''));
                $city = trim((string)($_POST['city'] ?? ''));
                if ($name === '') throw new InputError("Le nom de l'école est obligatoire.");
                if ($id === 0) {
                    if (!is_super()) go('');
                    $db->prepare('INSERT INTO faceid_schools (name, city, active, created_at) VALUES (?, ?, 1, ?)')
                        ->execute([$name, $city, now()]);
                    go('page=school&id=' . $db->lastInsertId(), 'École créée.');
                }
                allowed_school($db, $id);
                $active = is_super() ? (isset($_POST['active']) ? 1 : 0) : 1;
                $db->prepare('UPDATE faceid_schools SET name = ?, city = ?, active = ? WHERE id = ?')
                    ->execute([$name, $city, $active, $id]);
                go("page=school&id=$id", 'École enregistrée.');

            case 'mgmt_save':
                $school = allowed_school($db, (int)($_POST['id'] ?? 0));
                $url = trim((string)($_POST['mgmt_url'] ?? ''));
                $record = trim((string)($_POST['mgmt_record_url'] ?? ''));
                $key = trim((string)($_POST['mgmt_key'] ?? ''));
                $enabled = isset($_POST['mgmt_enabled']) ? 1 : 0;
                if ($url !== '' && !is_http_url($url)) throw new InputError("L'adresse de l'API doit commencer par http:// ou https://.");
                if ($record !== '' && !is_http_url($record)) throw new InputError("L'adresse des fiches doit commencer par http:// ou https://.");
                if ($enabled && $url === '') throw new InputError("Renseignez l'adresse de l'API avant d'activer.");
                if (strlen($url) > 500 || strlen($record) > 500 || strlen($key) > 255) throw new InputError('Valeur trop longue.');
                // Clé vide = on garde la clé déjà enregistrée.
                $db->prepare('UPDATE faceid_schools SET mgmt_enabled = ?, mgmt_url = ?, mgmt_record_url = ?,
                    mgmt_key = IF(? = \'\', mgmt_key, ?) WHERE id = ?')
                    ->execute([$enabled, $url, $record, $key, $key, $school['id']]);
                go('page=school&id=' . $school['id'], 'Système de gestion enregistré.');

            case 'mgmt_test':
                $school = allowed_school($db, (int)($_POST['id'] ?? 0));
                $matricule = trim((string)($_POST['matricule'] ?? ''));
                if ($matricule === '') throw new InputError('Saisissez un matricule à tester.');
                if ($school['mgmt_url'] === '') throw new InputError("Enregistrez d'abord l'adresse de l'API.");
                try {
                    $r = mgmt_lookup($school, $matricule);
                    $_SESSION['mgmt_test'] = ['ok' => true, 'matricule' => $matricule] + $r;
                } catch (RuntimeException $e) {
                    $_SESSION['mgmt_test'] = ['ok' => false, 'matricule' => $matricule, 'error' => $e->getMessage()];
                }
                go('page=school&id=' . $school['id']);

            case 'school_delete':
                if (!is_super()) go('');
                $id = (int)($_POST['id'] ?? 0);
                $db->prepare('DELETE FROM faceid_schools WHERE id = ?')->execute([$id]);
                go('', 'École supprimée, avec ses comptes et ses fiches.');

            case 'user_create':
                $schoolId = (int)($_POST['school_id'] ?? 0);
                allowed_school($db, $schoolId);
                $username = trim((string)($_POST['username'] ?? ''));
                $fullName = trim((string)($_POST['full_name'] ?? ''));
                $password = (string)($_POST['password'] ?? '');
                $role = is_super() && ($_POST['role'] ?? '') === 'admin' ? 'admin' : 'agent';
                if (!valid_username($username)) throw new InputError('Identifiant invalide (3 caractères min., lettres, chiffres, . _ -).');
                if ($fullName === '') throw new InputError('Le nom complet est obligatoire.');
                if (strlen($password) < 6) throw new InputError('Mot de passe : 6 caractères minimum.');
                $st = $db->prepare('SELECT 1 FROM faceid_users WHERE username = ?');
                $st->execute([$username]);
                if ($st->fetchColumn() !== false) throw new InputError('Cet identifiant est déjà utilisé.');
                $all = $role === 'admin' ? 1 : 0;
                $db->prepare("INSERT INTO faceid_users (school_id, username, password_hash, full_name, phone,
                    role, status, perm_scan, perm_edit, perm_delete, perm_sensitive, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, 'active', 1, ?, ?, ?, ?)")
                    ->execute([$schoolId, $username, hash_password($password), $fullName,
                        trim((string)($_POST['phone'] ?? '')), $role, $all, $all, $all, now()]);
                go("page=school&id=$schoolId", 'Compte créé.');

            case 'user_update':
                $u = load_user($db, (int)($_POST['id'] ?? 0));
                $self = !is_super() && (int)$u['id'] === (int)$_SESSION['who']['id'];
                if ($self) throw new InputError('Vous ne pouvez pas modifier votre propre compte ici.');
                if (!is_super() && $u['role'] === 'admin') throw new InputError('Seul le super-administrateur modifie un administrateur.');
                $status = (string)($_POST['status'] ?? $u['status']);
                if (!in_array($status, USER_STATUSES, true)) throw new InputError('Statut invalide.');
                $perms = [];
                foreach (array_keys(PERMISSIONS) as $k) $perms[] = isset($_POST[$k]) ? 1 : 0;
                $db->prepare('UPDATE faceid_users SET status = ?, perm_scan = ?, perm_edit = ?,
                    perm_delete = ?, perm_sensitive = ? WHERE id = ?')
                    ->execute(array_merge([$status], $perms, [$u['id']]));
                if ($status !== 'active') {
                    // Déconnecte immédiatement les téléphones de ce compte.
                    $db->prepare('DELETE FROM faceid_tokens WHERE user_id = ?')->execute([$u['id']]);
                }
                go('page=school&id=' . $u['school_id'], 'Compte « ' . $u['username'] . ' » mis à jour.');

            case 'user_password':
                $u = load_user($db, (int)($_POST['id'] ?? 0));
                if (!is_super() && $u['role'] === 'admin' && (int)$u['id'] !== (int)$_SESSION['who']['id']) {
                    throw new InputError('Seul le super-administrateur modifie un administrateur.');
                }
                $password = (string)($_POST['password'] ?? '');
                if (strlen($password) < 6) throw new InputError('Mot de passe : 6 caractères minimum.');
                $db->prepare('UPDATE faceid_users SET password_hash = ? WHERE id = ?')
                    ->execute([hash_password($password), $u['id']]);
                $db->prepare('DELETE FROM faceid_tokens WHERE user_id = ?')->execute([$u['id']]);
                go('page=school&id=' . $u['school_id'], 'Mot de passe changé.');

            case 'user_delete':
                $u = load_user($db, (int)($_POST['id'] ?? 0));
                if (!is_super() && ($u['role'] === 'admin')) throw new InputError('Seul le super-administrateur supprime un administrateur.');
                $db->prepare('DELETE FROM faceid_users WHERE id = ?')->execute([$u['id']]);
                go('page=school&id=' . $u['school_id'], 'Compte supprimé.');

            case 'person_save':
                $p = load_person($db, (string)($_POST['id'] ?? ''));
                $f = person_fields($_POST);
                $set = implode(', ', array_map(function ($c) { return "$c = ?"; }, array_keys($f)));
                $db->prepare("UPDATE faceid_people SET $set, updated_at = ? WHERE id = ?")
                    ->execute(array_merge(array_values($f), [now(), $p['id']]));
                go('page=people&id=' . $p['school_id'], 'Fiche enregistrée.');

            case 'person_delete':
                $p = load_person($db, (string)($_POST['id'] ?? ''));
                $db->prepare('DELETE FROM faceid_people WHERE id = ?')->execute([$p['id']]);
                go('page=people&id=' . $p['school_id'], 'Fiche supprimée.');
        }
    } catch (InputError $e) {
        if (!isset($_SESSION['who'])) {
            $error = $e->getMessage();
        } else {
            // Retour à la page d'où vient le formulaire, avec le message.
            $_SESSION['error'] = $e->getMessage();
            $back = (string)(parse_url((string)($_SERVER['HTTP_REFERER'] ?? ''), PHP_URL_QUERY) ?? '');
            go($back);
        }
    }
}

if (isset($_SESSION['flash'])) {
    $flash = $_SESSION['flash'];
    unset($_SESSION['flash']);
}
if (isset($_SESSION['error'])) {
    $error = $_SESSION['error'];
    unset($_SESSION['error']);
}
$who = $_SESSION['who'] ?? null;
if ($who === null) $page = 'login';
elseif ($page === '' && !is_super()) go('page=school&id=' . $who['school_id']);

// ------------------------------------------------------------ affichage

function layout_start(string $title, ?array $who): void
{
    ?><!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title><?= h($title) ?> · FaceID École</title>
<style>
:root{--night:#1E2A78;--teal:#00B4D8;--cyan:#48CAE4;--bg:#F4F7FD;--card:#fff;--text:#1B2240;--muted:#667090;
--ok:#10B981;--warn:#F59E0B;--bad:#EF4444;--line:#E3E8F4}
*{box-sizing:border-box}body{margin:0;font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;background:var(--bg);color:var(--text)}
header{background:linear-gradient(120deg,var(--night),var(--teal));color:#fff;padding:16px 24px;display:flex;align-items:center;gap:16px;flex-wrap:wrap}
header h1{font-size:20px;margin:0;flex:1}header a{color:#fff;text-decoration:none;opacity:.9}header form{margin:0}
main{max-width:1100px;margin:24px auto;padding:0 16px}
.card{background:var(--card);border-radius:16px;box-shadow:0 2px 10px rgba(30,42,120,.07);padding:20px;margin-bottom:20px}
h2{margin:0 0 14px;font-size:18px}h3{margin:18px 0 10px;font-size:15px;color:var(--muted)}
table{width:100%;border-collapse:collapse;font-size:14px}th,td{text-align:left;padding:10px 8px;border-bottom:1px solid var(--line);vertical-align:middle}
th{color:var(--muted);font-weight:600;font-size:12px;text-transform:uppercase;letter-spacing:.03em}
.table-wrap{overflow-x:auto}
input,select,textarea{font:inherit;padding:9px 11px;border:1px solid var(--line);border-radius:10px;background:#fff;color:var(--text);width:100%}
textarea{min-height:70px}label{display:block;font-size:13px;color:var(--muted);margin-bottom:4px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:14px}
.row{display:flex;gap:8px;flex-wrap:wrap;align-items:center}
button,.btn{font:inherit;border:0;border-radius:10px;padding:9px 16px;cursor:pointer;background:var(--teal);color:#fff;text-decoration:none;display:inline-block;font-weight:600}
.btn-night{background:var(--night)}.btn-ghost{background:transparent;color:var(--night);border:1px solid var(--line)}
.btn-bad{background:var(--bad)}.btn-ok{background:var(--ok)}.btn-sm{padding:6px 10px;font-size:13px}
.badge{white-space:nowrap;display:inline-block;padding:3px 10px;border-radius:99px;font-size:12px;font-weight:600;color:#fff}
.b-pending{background:var(--warn)}.b-active{background:var(--ok)}.b-blocked{background:var(--bad)}
.flash{background:#E6FAF4;border:1px solid #9FE3CC;color:#07614A;padding:12px 16px;border-radius:12px;margin-bottom:16px}
.error{background:#FDECEC;border:1px solid #F5B5B5;color:#8E1F1F;padding:12px 16px;border-radius:12px;margin-bottom:16px}
.tabs{display:flex;gap:6px;margin-bottom:16px}.tabs a{padding:8px 16px;border-radius:99px;text-decoration:none;color:var(--night);background:#E4ECFB;font-weight:600}
.tabs a.on{background:var(--night);color:#fff}
.avatar{width:44px;height:44px;border-radius:50%;object-fit:cover;background:#DDE6F7;display:block}
.perms label{display:flex;align-items:center;gap:6px;color:var(--text);margin:2px 0;font-size:13px}.perms input{width:auto}
.muted{color:var(--muted);font-size:13px}.login{max-width:380px;margin:60px auto}
.stat{font-size:28px;font-weight:700;color:var(--night)}
@media (max-width:700px){table.cards,table.cards tbody,table.cards tr,table.cards td{display:block;width:100%}
table.cards tr:first-child{display:none}table.cards tr{border:1px solid var(--line);border-radius:14px;padding:6px 10px;margin-bottom:12px}
table.cards td{border:0;padding:6px 0}header h1{font-size:17px}}
@media (prefers-color-scheme:dark){:root{--bg:#0E1330;--card:#171E45;--text:#E8ECFA;--muted:#9AA5CC;--line:#2A3366}
input,select,textarea{background:#0F1538}.tabs a{background:#243070;color:#DCE4FF}.btn-ghost{color:#DCE4FF}}
</style>
</head>
<body>
<header>
  <h1>🛡️ FaceID École — Administration</h1>
  <?php if ($who !== null): ?>
    <?php if ($who['super']): ?><a href="admin.php">Écoles</a><?php endif; ?>
    <span><?= h($who['name']) ?></span>
    <form method="post"><?= csrf_field() ?><input type="hidden" name="action" value="logout">
      <button class="btn-sm btn-ghost" style="color:#fff;border-color:rgba(255,255,255,.5)">Déconnexion</button></form>
  <?php endif; ?>
</header>
<main>
<?php
}

function messages(?string $flash, ?string $error): void
{
    if ($flash) echo '<div class="flash">' . h($flash) . '</div>';
    if ($error) echo '<div class="error">' . h($error) . '</div>';
}

if ($page === 'login') {
    layout_start('Connexion', null);
    messages($flash, $error); ?>
    <div class="card login">
      <h2>Connexion</h2>
      <?php if ($defaultPassword): ?>
        <p class="error">Le super-administrateur est désactivé tant que <code>ADMIN_PASSWORD</code>
        n'est pas changé dans <code>config.php</code>.</p>
      <?php endif; ?>
      <form method="post">
        <input type="hidden" name="action" value="login">
        <label>Identifiant</label><input name="username" required autofocus><br><br>
        <label>Mot de passe</label><input name="password" type="password" required><br><br>
        <button style="width:100%">Se connecter</button>
      </form>
    </div>
<?php
} elseif ($page === '' && is_super()) {
    $schools = $db->query("SELECT s.*,
        (SELECT COUNT(*) FROM faceid_users u WHERE u.school_id = s.id) AS users,
        (SELECT COUNT(*) FROM faceid_users u WHERE u.school_id = s.id AND u.status = 'pending') AS pending,
        (SELECT COUNT(*) FROM faceid_people p WHERE p.school_id = s.id) AS people
        FROM faceid_schools s ORDER BY s.name")->fetchAll();
    layout_start('Écoles', $who);
    messages($flash, $error); ?>
    <div class="card">
      <h2>Écoles</h2>
      <div class="table-wrap"><table>
        <tr><th>École</th><th>Ville</th><th>Comptes</th><th>En attente</th><th>Personnes</th><th>État</th><th></th></tr>
        <?php foreach ($schools as $s): ?>
          <tr>
            <td><strong><?= h($s['name']) ?></strong></td><td><?= h($s['city']) ?></td>
            <td><?= (int)$s['users'] ?></td>
            <td><?= (int)$s['pending'] ? '<span class="badge b-pending">' . (int)$s['pending'] . '</span>' : '0' ?></td>
            <td><?= (int)$s['people'] ?></td>
            <td><?= $s['active'] ? '<span class="badge b-active">Active</span>' : '<span class="badge b-blocked">Désactivée</span>' ?></td>
            <td><a class="btn btn-sm" href="admin.php?page=school&id=<?= (int)$s['id'] ?>">Gérer</a></td>
          </tr>
        <?php endforeach; ?>
        <?php if (!$schools): ?><tr><td colspan="7" class="muted">Aucune école pour l'instant.</td></tr><?php endif; ?>
      </table></div>
    </div>
    <div class="card">
      <h2>Nouvelle école</h2>
      <form method="post" class="row"><?= csrf_field() ?>
        <input type="hidden" name="action" value="school_save">
        <div style="flex:2;min-width:200px"><label>Nom</label><input name="name" required></div>
        <div style="flex:1;min-width:150px"><label>Ville</label><input name="city"></div>
        <div style="align-self:flex-end"><button>Créer</button></div>
      </form>
    </div>
<?php
} elseif ($page === 'school') {
    $school = allowed_school($db, (int)($_GET['id'] ?? 0));
    $st = $db->prepare("SELECT * FROM faceid_users WHERE school_id = ?
        ORDER BY FIELD(status, 'pending', 'active', 'blocked'), full_name");
    $st->execute([$school['id']]);
    $users = $st->fetchAll();
    $st = $db->prepare('SELECT COUNT(*) FROM faceid_people WHERE school_id = ?');
    $st->execute([$school['id']]);
    $peopleCount = (int)$st->fetchColumn();
    layout_start($school['name'], $who);
    messages($flash, $error); ?>
    <div class="tabs">
      <a class="on" href="admin.php?page=school&id=<?= (int)$school['id'] ?>">Comptes</a>
      <a href="admin.php?page=people&id=<?= (int)$school['id'] ?>">Élèves et personnel (<?= $peopleCount ?>)</a>
    </div>
    <div class="card">
      <h2><?= h($school['name']) ?></h2>
      <form method="post" class="row"><?= csrf_field() ?>
        <input type="hidden" name="action" value="school_save"><input type="hidden" name="id" value="<?= (int)$school['id'] ?>">
        <div style="flex:2;min-width:200px"><label>Nom</label><input name="name" value="<?= h($school['name']) ?>" required></div>
        <div style="flex:1;min-width:150px"><label>Ville</label><input name="city" value="<?= h($school['city']) ?>"></div>
        <?php if (is_super()): ?>
          <div class="perms" style="align-self:flex-end"><label><input type="checkbox" name="active" <?= $school['active'] ? 'checked' : '' ?>> Active</label></div>
        <?php endif; ?>
        <div style="align-self:flex-end"><button class="btn-night">Enregistrer</button></div>
      </form>
    </div>

    <?php $test = $_SESSION['mgmt_test'] ?? null; unset($_SESSION['mgmt_test']); ?>
    <div class="card">
      <h2>Système de gestion de l'école <?= $school['mgmt_enabled'] ? '<span class="badge b-active">Activé</span>' : '<span class="badge" style="background:#8A94B5">Désactivé</span>' ?></h2>
      <p class="muted">Facultatif. Si l'école a un système de gestion, l'agent pourra saisir un matricule
        dans l'application pour remplir la fiche automatiquement, et ouvrir la fiche de l'élève
        dans ce système après la reconnaissance. Voir « Contrat système de gestion » dans LISEZMOI.md.</p>
      <form method="post" class="grid"><?= csrf_field() ?>
        <input type="hidden" name="action" value="mgmt_save"><input type="hidden" name="id" value="<?= (int)$school['id'] ?>">
        <div style="grid-column:1/-1"><label>Adresse de l'API (recherche par matricule)</label>
          <input name="mgmt_url" value="<?= h($school['mgmt_url']) ?>" placeholder="https://gestion.mon-ecole.com/custom/ecole/faceid_eleve.php"></div>
        <div style="grid-column:1/-1"><label>Adresse d'une fiche élève — <code>{matricule}</code> sera remplacé</label>
          <input name="mgmt_record_url" value="<?= h($school['mgmt_record_url']) ?>" placeholder="https://gestion.mon-ecole.com/custom/ecole/eleve.php?ref={matricule}"></div>
        <div><label>Clé d'accès <?= $school['mgmt_key'] !== '' ? '(enregistrée — laisser vide pour la garder)' : '' ?></label>
          <input name="mgmt_key" type="password" autocomplete="new-password" placeholder="<?= $school['mgmt_key'] !== '' ? '••••••••' : '' ?>"></div>
        <div class="perms" style="align-self:end"><label><input type="checkbox" name="mgmt_enabled" <?= $school['mgmt_enabled'] ? 'checked' : '' ?>> Activer la liaison</label></div>
        <div style="align-self:end"><button class="btn-night">Enregistrer</button></div>
      </form>
      <h3>Tester</h3>
      <form method="post" class="row"><?= csrf_field() ?>
        <input type="hidden" name="action" value="mgmt_test"><input type="hidden" name="id" value="<?= (int)$school['id'] ?>">
        <input name="matricule" placeholder="Matricule d'un élève" style="max-width:240px" value="<?= h($test['matricule'] ?? '') ?>">
        <button class="btn-ghost">Tester la recherche</button>
      </form>
      <?php if ($test): ?>
        <?php if (!$test['ok']): ?>
          <div class="error" style="margin-top:12px"><?= h($test['error']) ?></div>
        <?php elseif (!$test['found']): ?>
          <div class="error" style="margin-top:12px">Connexion réussie, mais aucun élève avec le matricule « <?= h($test['matricule']) ?> ».</div>
        <?php else: ?>
          <div class="flash" style="margin-top:12px">Élève trouvé :
            <?php foreach ($test['fields'] as $k => $v): ?><br><strong><?= h($k) ?></strong> : <?= h($v) ?><?php endforeach; ?>
            <?php if ($test['record_url'] !== ''): ?><br><a href="<?= h($test['record_url']) ?>" target="_blank" rel="noopener">Ouvrir la fiche</a><?php endif; ?>
          </div>
        <?php endif; ?>
      <?php endif; ?>
    </div>

    <div class="card">
      <h2>Comptes de l'école</h2>
      <p class="muted">Les agents créent leur compte dans l'application : il apparaît ici « En attente ».
        Autorisez-le et choisissez ses permissions. Un compte bloqué est déconnecté immédiatement.</p>
      <div class="table-wrap"><table class="cards">
        <tr><th>Nom</th><th>Identifiant</th><th>État</th><th>Permissions</th><th>Actions</th></tr>
        <?php foreach ($users as $u):
            $isAdmin = $u['role'] === 'admin';
            $self = !is_super() && (int)$u['id'] === (int)$who['id'];
            $locked = $self || ($isAdmin && !is_super()); ?>
          <tr>
            <td><strong><?= h($u['full_name']) ?></strong><?= $isAdmin ? ' <span class="badge b-active" style="background:var(--night)">Admin</span>' : '' ?>
              <div class="muted"><?= h($u['phone']) ?></div>
              <div class="muted">Inscrit le <?= h(substr($u['created_at'], 0, 10)) ?><?= $u['last_login_at'] ? ' · connecté le ' . h(substr($u['last_login_at'], 0, 10)) : '' ?></div></td>
            <td><?= h($u['username']) ?></td>
            <td><span class="badge b-<?= h($u['status']) ?>"><?= h(STATUS_LABELS[$u['status']] ?? $u['status']) ?></span></td>
            <td>
              <?php if ($locked || $isAdmin): ?>
                <span class="muted"><?= $isAdmin ? 'Toutes' : '—' ?></span>
              <?php else: ?>
              <form method="post" class="perms" id="f<?= (int)$u['id'] ?>"><?= csrf_field() ?>
                <input type="hidden" name="action" value="user_update"><input type="hidden" name="id" value="<?= (int)$u['id'] ?>">
                <input type="hidden" name="status" value="<?= h($u['status']) ?>">
                <?php foreach (PERMISSIONS as $k => $label): ?>
                  <label><input type="checkbox" name="<?= $k ?>" <?= (int)$u[$k] ? 'checked' : '' ?>> <?= h($label) ?></label>
                <?php endforeach; ?>
                <button class="btn-sm btn-night" style="margin-top:6px">Enregistrer</button>
              </form>
              <?php endif; ?>
            </td>
            <td>
              <?php if (!$locked): ?>
              <div class="row">
                <?php foreach (['active' => ['Autoriser', 'btn-ok'], 'blocked' => ['Bloquer', 'btn-bad']] as $st2 => [$lbl, $cls]):
                    if ($u['status'] === $st2) continue; ?>
                  <form method="post"><?= csrf_field() ?>
                    <input type="hidden" name="action" value="user_update"><input type="hidden" name="id" value="<?= (int)$u['id'] ?>">
                    <input type="hidden" name="status" value="<?= $st2 ?>">
                    <?php foreach (array_keys(PERMISSIONS) as $k): if ((int)$u[$k] || $isAdmin): ?>
                      <input type="hidden" name="<?= $k ?>" value="1"><?php endif; endforeach; ?>
                    <button class="btn-sm <?= $cls ?>"><?= $st2 === 'active' && $u['status'] === 'blocked' ? 'Débloquer' : $lbl ?></button>
                  </form>
                <?php endforeach; ?>
                <form method="post" onsubmit="return confirm('Supprimer ce compte ?')"><?= csrf_field() ?>
                  <input type="hidden" name="action" value="user_delete"><input type="hidden" name="id" value="<?= (int)$u['id'] ?>">
                  <button class="btn-sm btn-ghost">Supprimer</button>
                </form>
              </div>
              <?php endif; ?>
              <?php if (!$isAdmin || is_super() || $self): ?>
              <form method="post" class="row" style="margin-top:6px"><?= csrf_field() ?>
                <input type="hidden" name="action" value="user_password"><input type="hidden" name="id" value="<?= (int)$u['id'] ?>">
                <input name="password" type="password" placeholder="Nouveau mot de passe" minlength="6" style="max-width:180px">
                <button class="btn-sm btn-ghost">Changer</button>
              </form>
              <?php endif; ?>
            </td>
          </tr>
        <?php endforeach; ?>
        <?php if (!$users): ?><tr><td colspan="5" class="muted">Aucun compte.</td></tr><?php endif; ?>
      </table></div>

      <h3>Créer un compte</h3>
      <form method="post" class="grid"><?= csrf_field() ?>
        <input type="hidden" name="action" value="user_create"><input type="hidden" name="school_id" value="<?= (int)$school['id'] ?>">
        <div><label>Nom complet</label><input name="full_name" required></div>
        <div><label>Identifiant</label><input name="username" required pattern="[A-Za-z0-9._\-]{3,64}"></div>
        <div><label>Téléphone</label><input name="phone"></div>
        <div><label>Mot de passe</label><input name="password" type="password" required minlength="6"></div>
        <?php if (is_super()): ?>
          <div><label>Rôle</label><select name="role"><option value="agent">Agent</option><option value="admin">Administrateur de l'école</option></select></div>
        <?php endif; ?>
        <div style="align-self:end"><button>Créer</button></div>
      </form>
    </div>

    <?php if (is_super()): ?>
    <div class="card">
      <h2>Zone dangereuse</h2>
      <form method="post" onsubmit="return confirm('Supprimer l\'école, tous ses comptes et toutes ses fiches ?')"><?= csrf_field() ?>
        <input type="hidden" name="action" value="school_delete"><input type="hidden" name="id" value="<?= (int)$school['id'] ?>">
        <button class="btn-bad">Supprimer cette école</button>
      </form>
    </div>
    <?php endif; ?>
<?php
} elseif ($page === 'people') {
    $school = allowed_school($db, (int)($_GET['id'] ?? 0));
    $q = trim((string)($_GET['q'] ?? ''));
    $type = (string)($_GET['type'] ?? '');
    $sql = 'SELECT id, type, matricule, first_name, last_name, class_level, job_title, status,
        (photo IS NOT NULL) AS has_photo FROM faceid_people WHERE school_id = ?';
    $args = [$school['id']];
    if ($q !== '') {
        $sql .= ' AND (first_name LIKE ? OR last_name LIKE ? OR matricule LIKE ? OR class_level LIKE ?)';
        array_push($args, "%$q%", "%$q%", "%$q%", "%$q%");
    }
    if (isset(TYPE_LABELS[$type])) {
        $sql .= ' AND type = ?';
        $args[] = $type;
    }
    $st = $db->prepare($sql . ' ORDER BY last_name, first_name LIMIT 500');
    $st->execute($args);
    $people = $st->fetchAll();
    layout_start('Élèves et personnel', $who);
    messages($flash, $error); ?>
    <div class="tabs">
      <a href="admin.php?page=school&id=<?= (int)$school['id'] ?>">Comptes</a>
      <a class="on" href="admin.php?page=people&id=<?= (int)$school['id'] ?>">Élèves et personnel</a>
    </div>
    <div class="card">
      <h2><?= h($school['name']) ?> — élèves et personnel</h2>
      <p class="muted">L'ajout d'une personne se fait dans l'application (il faut enregistrer son visage).</p>
      <form class="row" method="get" style="margin-bottom:12px">
        <input type="hidden" name="page" value="people"><input type="hidden" name="id" value="<?= (int)$school['id'] ?>">
        <input name="q" value="<?= h($q) ?>" placeholder="Nom, matricule, classe…" style="flex:1;min-width:180px">
        <select name="type" style="max-width:180px"><option value="">Tous</option>
          <?php foreach (TYPE_LABELS as $k => $l): ?><option value="<?= $k ?>" <?= $type === $k ? 'selected' : '' ?>><?= $l ?></option><?php endforeach; ?>
        </select>
        <button class="btn-night">Rechercher</button>
      </form>
      <div class="table-wrap"><table class="cards">
        <tr><th></th><th>Nom</th><th>Type</th><th>Classe / fonction</th><th>Matricule</th><th>Statut</th><th></th></tr>
        <?php foreach ($people as $p): ?>
          <tr>
            <td><?php if ($p['has_photo']): ?><img class="avatar" src="admin.php?page=photo&id=<?= h($p['id']) ?>" alt=""><?php else: ?><span class="avatar"></span><?php endif; ?></td>
            <td><strong><?= h(person_name($p)) ?></strong></td>
            <td><?= h(TYPE_LABELS[$p['type']] ?? $p['type']) ?></td>
            <td><?= h($p['type'] === 'eleve' ? $p['class_level'] : $p['job_title']) ?></td>
            <td><?= h($p['matricule']) ?></td>
            <td><?= h(PERSON_STATUS_LABELS[$p['status']] ?? $p['status']) ?></td>
            <td><a class="btn btn-sm" href="admin.php?page=person&id=<?= h($p['id']) ?>">Ouvrir</a></td>
          </tr>
        <?php endforeach; ?>
        <?php if (!$people): ?><tr><td colspan="7" class="muted">Aucune fiche.</td></tr><?php endif; ?>
      </table></div>
    </div>
<?php
} elseif ($page === 'person') {
    $p = load_person($db, (string)($_GET['id'] ?? ''));
    layout_start(person_name($p), $who);
    messages($flash, $error);
    $field = function (string $name, string $label, string $type = 'text') use ($p): void {
        echo '<div><label>' . h($label) . '</label><input type="' . $type . '" name="' . $name . '" value="' . h($p[$name] ?? '') . '"></div>';
    }; ?>
    <div class="tabs">
      <a href="admin.php?page=people&id=<?= (int)$p['school_id'] ?>">← Retour à la liste</a>
    </div>
    <div class="card">
      <div class="row" style="margin-bottom:16px">
        <?php if ($p['photo'] !== null): ?><img class="avatar" style="width:96px;height:96px" src="admin.php?page=photo&id=<?= h($p['id']) ?>" alt=""><?php endif; ?>
        <div><h2 style="margin:0"><?= h(person_name($p)) ?></h2>
          <div class="muted">Créé le <?= h(substr($p['created_at'], 0, 10)) ?> · modifié le <?= h(substr($p['updated_at'], 0, 10)) ?></div></div>
      </div>
      <form method="post"><?= csrf_field() ?>
        <input type="hidden" name="action" value="person_save"><input type="hidden" name="id" value="<?= h($p['id']) ?>">
        <h3>Identité</h3>
        <div class="grid">
          <div><label>Type</label><select name="type"><?php foreach (TYPE_LABELS as $k => $l): ?><option value="<?= $k ?>" <?= $p['type'] === $k ? 'selected' : '' ?>><?= $l ?></option><?php endforeach; ?></select></div>
          <?php $field('last_name', 'Nom'); $field('first_name', 'Prénom'); $field('matricule', 'Matricule'); ?>
          <div><label>Sexe</label><select name="sex"><?php foreach (['' => '—', 'M' => 'Masculin', 'F' => 'Féminin'] as $k => $l): ?><option value="<?= $k ?>" <?= $p['sex'] === $k ? 'selected' : '' ?>><?= $l ?></option><?php endforeach; ?></select></div>
          <?php $field('birth_date', 'Date de naissance', 'date'); ?>
          <div><label>Statut</label><select name="status"><?php foreach (PERSON_STATUS_LABELS as $k => $l): ?><option value="<?= $k ?>" <?= $p['status'] === $k ? 'selected' : '' ?>><?= $l ?></option><?php endforeach; ?></select></div>
        </div>
        <h3>Scolarité / fonction</h3>
        <div class="grid">
          <?php $field('class_level', 'Classe / niveau'); $field('school_year', 'Année scolaire'); $field('enrollment_date', "Date d'inscription", 'date'); $field('job_title', 'Fonction (personnel)'); ?>
        </div>
        <h3>Parents / contact</h3>
        <div class="grid">
          <?php $field('parent_name', 'Nom du parent'); $field('parent_phone', 'Téléphone', 'tel'); $field('address', 'Adresse'); ?>
        </div>
        <h3>Santé et remarques</h3>
        <div class="grid">
          <div><label>Informations médicales</label><textarea name="medical"><?= h($p['medical']) ?></textarea></div>
          <div><label>Remarques</label><textarea name="notes"><?= h($p['notes']) ?></textarea></div>
        </div>
        <br><button>Enregistrer</button>
      </form>
    </div>
    <div class="card">
      <form method="post" onsubmit="return confirm('Supprimer définitivement cette fiche ?')"><?= csrf_field() ?>
        <input type="hidden" name="action" value="person_delete"><input type="hidden" name="id" value="<?= h($p['id']) ?>">
        <button class="btn-bad">Supprimer cette fiche</button>
      </form>
    </div>
<?php
} else {
    go('');
}
?>
<p class="muted" style="text-align:center;margin:28px 0">Développé par Abdou · 36629518</p>
</main>
</body>
</html>
