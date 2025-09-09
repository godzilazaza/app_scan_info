<?php
// /api/upload.php
require_once __DIR__ . '/helpers.php';
cors();

/**
 * ทุก response ส่งเป็น JSON และมี CORS เสมอ
 */
function json_err($code, $msg, $extra = []) {
  http_response_code($code);
  header('Content-Type: application/json; charset=utf-8');
  echo json_encode(['ok' => false, 'error' => $msg] + $extra, JSON_UNESCAPED_UNICODE);
  exit;
}

// Preflight
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }

// GET ใช้เช็คว่าสคริปต์ทำงาน/ผ่าน CORS (ไม่อัปโหลด)
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
  header('Content-Type: application/json; charset=utf-8');
  echo json_encode(['ok' => true, 'endpoint' => 'upload', 'time' => date('c')]);
  exit;
}

// รับไฟล์เฉพาะ POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
  json_err(405, 'METHOD_NOT_ALLOWED');
}

// ตรวจไฟล์
if (!isset($_FILES['file'])) {
  json_err(400, 'NO_FILE');
}

$f = $_FILES['file'];
if (!is_uploaded_file($f['tmp_name'])) {
  json_err(400, 'INVALID_UPLOAD');
}

// จำกัดขนาด (≤ 2MB)
$maxSize = 2 * 1024 * 1024;
if ($f['size'] > $maxSize) {
  json_err(400, 'FILE_TOO_LARGE', ['max' => $maxSize]);
}

// ตรวจชนิดไฟล์ (พยายามใช้ finfo, fallback เป็น getimagesize)
$allowed = ['image/jpeg' => '.jpg', 'image/png' => '.png', 'image/webp' => '.webp'];
$mime = null;

if (function_exists('finfo_open')) {
  $fi = finfo_open(FILEINFO_MIME_TYPE);
  if ($fi) {
    $mime = finfo_file($fi, $f['tmp_name']);
    finfo_close($fi);
  }
}
if (!$mime && function_exists('getimagesize')) {
  $info = @getimagesize($f['tmp_name']);
  if ($info && isset($info['mime'])) $mime = $info['mime'];
}
// ถ้าหาไม่ได้จริง ๆ ใช้นามสกุลเดิม (เสี่ยง) – ที่นี่ไม่อนุญาต
if (!$mime || !isset($allowed[$mime])) {
  json_err(400, 'INVALID_TYPE', ['allow' => array_keys($allowed), 'got' => $mime]);
}

$ext = $allowed[$mime];

// เตรียมโฟลเดอร์อัปโหลด (อยู่นอก /api)
$uploadDir = realpath(__DIR__ . '/..') . '/uploads/';
$baseUrl   = 'https://weerispost.online/uploads/';

if (!is_dir($uploadDir) && !@mkdir($uploadDir, 0755, true)) {
  json_err(500, 'MKDIR_FAILED', ['dir' => $uploadDir]);
}
if (!is_writable($uploadDir)) {
  json_err(500, 'DIR_NOT_WRITABLE', ['dir' => $uploadDir]);
}

// ตั้งชื่อไฟล์แบบ unique
$basename = 'p_' . date('Ymd_His') . '_' . bin2hex(random_bytes(4)) . $ext;
$target = $uploadDir . $basename;

// ย้ายไฟล์
if (!move_uploaded_file($f['tmp_name'], $target)) {
  json_err(500, 'MOVE_FAILED');
}

// สำเร็จ
header('Content-Type: application/json; charset=utf-8');
echo json_encode([
  'ok'  => true,
  'url' => $baseUrl . $basename
], JSON_UNESCAPED_UNICODE);
