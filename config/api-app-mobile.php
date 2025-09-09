<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: content-type, authorization');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') exit;

require __DIR__ . '/db.php'; // $conn (mysqli), utf8mb4

function read_input(): array {
  $ct  = $_SERVER['CONTENT_TYPE'] ?? '';
  $raw = file_get_contents('php://input') ?: '';
  if (stripos($ct, 'application/json') !== false && $raw !== '') {
    $j = json_decode($raw, true);
    if (json_last_error() === JSON_ERROR_NONE && is_array($j)) return $j;
  }
  return $_POST;
}

$action = $_GET['action'] ?? '';

try {
  if ($action === 'dbcheck') {
    $row = $conn->query("SELECT DATABASE() db, VERSION() ver, @@hostname host")->fetch_assoc();
    echo json_encode(['ok'=>true,'driver'=>'mysqli','db'=>$row['db'],'server'=>$row['ver'],'host'=>$row['host']]); exit;
  }

  if ($action === 'register' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $d = read_input();
    $username = trim((string)($d['username'] ?? ''));
    $email    = trim((string)($d['email'] ?? ''));
    $pass     = (string)($d['password'] ?? $d['pass'] ?? '');

    // ต้องมีอย่างน้อย: email + password (ถ้าแอพมีช่อง username ก็ส่งมาด้วย)
    if ($email === '' || $pass === '') { echo json_encode(['ok'=>false,'error'=>'Missing email or password']); exit; }
    if (strlen($pass) < 6) { echo json_encode(['ok'=>false,'error'=>'Password too short']); exit; }

    // ชน username/email ไหม (ถ้าส่ง username มาด้วย)
    if ($username !== '') {
      $stmt = $conn->prepare("SELECT id FROM users WHERE username=? LIMIT 1");
      $stmt->bind_param("s",$username); $stmt->execute(); $stmt->store_result();
      if ($stmt->num_rows>0) { echo json_encode(['ok'=>false,'error'=>'username exists']); exit; }
      $stmt->close();
    }
    $stmt = $conn->prepare("SELECT id FROM users WHERE email=? LIMIT 1");
    $stmt->bind_param("s",$email); $stmt->execute(); $stmt->store_result();
    if ($stmt->num_rows>0) { echo json_encode(['ok'=>false,'error'=>'email exists']); exit; }
    $stmt->close();

    // บันทึก (ใช้คอลัมน์ password ตามสคีมาของคุณ)
    $hash = password_hash($pass, PASSWORD_BCRYPT);
    if ($username === '') {
      // ถ้าไม่ได้ส่ง username มา จะลองสร้างจากอีเมลส่วนหน้า
      $username = explode('@',$email)[0];
    }
    $stmt = $conn->prepare("INSERT INTO users(username, email, password) VALUES(?,?,?)");
    $stmt->bind_param("sss", $username, $email, $hash);
    $stmt->execute();

    echo json_encode(['ok'=>true]); exit;
  }

  if ($action === 'login' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $d = read_input();
    $identity = trim((string)($d['email'] ?? $d['username'] ?? ''));
    $pass     = (string)($d['password'] ?? $d['pass'] ?? '');

    if ($identity === '' || $pass === '') { echo json_encode(['ok'=>false,'error'=>'Missing email/username or password']); exit; }

    // หาได้ทั้งสองแบบ: email หรือ username
    $stmt = $conn->prepare("SELECT id, password FROM users WHERE email=? OR username=? LIMIT 1");
    $stmt->bind_param("ss", $identity, $identity);
    $stmt->execute();
    $res = $stmt->get_result(); $row = $res->fetch_assoc();

    if (!$row || !password_verify($pass, $row['password'])) {
      echo json_encode(['ok'=>false,'error'=>'Invalid credentials']); exit;
    }

    $token = bin2hex(random_bytes(16)); // ตัวอย่าง token
    echo json_encode(['ok'=>true,'token'=>$token,'userId'=>(int)$row['id']]); exit;
  }

  http_response_code(404);
  echo json_encode(['ok'=>false,'error'=>'unknown action']);
} catch (Throwable $e) {
  http_response_code(500);
  echo json_encode(['ok'=>false,'error'=>'server error']);
}
