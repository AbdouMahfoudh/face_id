<?php
// Simulateur d'un système de gestion d'école, pour tester la liaison FaceID
// sans vraie école. Il respecte le « contrat système de gestion » (LISEZMOI.md).
//
// Réglages de test dans la page admin (fiche de l'école) :
//   Adresse de l'API   : http://VOTRE_SERVEUR/…/faceid_api/demo_gestion.php
//   Adresse d'une fiche : http://VOTRE_SERVEUR/…/faceid_api/demo_gestion.php?fiche={matricule}
//   Clé d'accès         : demo-faceid
// Matricules disponibles : E001, E002, E003, P001.
//
// ⚠️ Supprimez ce fichier une fois les tests terminés.
declare(strict_types=1);

const DEMO_KEY = 'demo-faceid';

const DEMO_PEOPLE = [
    'E001' => [
        'type' => 'eleve', 'matricule' => 'E001', 'first_name' => 'Amina', 'last_name' => 'Sow',
        'sex' => 'F', 'birth_date' => '2013-04-12', 'status' => 'actif', 'class_level' => '6e A',
        'school_year' => '2026-2027', 'enrollment_date' => '2024-09-15',
        'parent_name' => 'Moussa Sow', 'parent_phone' => '+222 36 00 00 01',
        'address' => 'Tevragh Zeina, Nouakchott', 'medical' => 'Asthme léger',
    ],
    'E002' => [
        'type' => 'eleve', 'matricule' => 'E002', 'first_name' => 'Mohamed', 'last_name' => 'Ould Ahmed',
        'sex' => 'M', 'class_level' => '5e B', 'parent_phone' => '+222 36 00 00 02',
    ],
    'E003' => [
        // Élève avec peu d'informations : les autres champs restent à remplir.
        'matricule' => 'E003', 'first_name' => 'Fatimetou', 'last_name' => 'Mint Salem',
    ],
    'P001' => [
        'type' => 'enseignant', 'matricule' => 'P001', 'first_name' => 'Ibrahima', 'last_name' => 'Diallo',
        'sex' => 'M', 'job_title' => 'Professeur de mathématiques',
    ],
];

$matricule = strtoupper(trim((string)($_GET['matricule'] ?? $_GET['fiche'] ?? '')));

// Page « fiche » ouverte depuis l'application, pour vérifier le lien.
if (isset($_GET['fiche'])) {
    header('Content-Type: text/html; charset=utf-8');
    $p = DEMO_PEOPLE[$matricule] ?? null;
    echo '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width">'
        . '<title>Fiche démo</title><body style="font-family:system-ui;padding:20px">'
        . '<h2>Système de gestion (démo)</h2>';
    if ($p === null) {
        echo '<p>Aucune fiche pour ce matricule.</p>';
    } else {
        foreach ($p as $k => $v) {
            echo '<p><b>' . htmlspecialchars($k) . '</b> : ' . htmlspecialchars($v) . '</p>';
        }
    }
    exit;
}

header('Content-Type: application/json; charset=utf-8');
if (!hash_equals(DEMO_KEY, (string)($_SERVER['HTTP_X_FACEID_KEY'] ?? ''))) {
    http_response_code(401);
    echo json_encode(['ok' => false, 'error' => 'Clé invalide'], JSON_UNESCAPED_UNICODE);
    exit;
}
$p = DEMO_PEOPLE[$matricule] ?? null;
echo json_encode(
    $p === null ? ['ok' => true, 'found' => false] : ['ok' => true, 'found' => true, 'student' => $p],
    JSON_UNESCAPED_UNICODE
);
