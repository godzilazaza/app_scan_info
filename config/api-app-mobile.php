<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: content-type, authorization');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') exit;

require __DIR__ . '/config_product.php'; // $conn_product (mysqli), utf8mb4

function read_input(): array {
  $ct  = $_SERVER['CONTENT_TYPE'] ?? '';
  $raw = file_get_contents('php://input') ?: '';
  if (stripos($ct, 'application/json') !== false && $raw !== '') {
    $j = json_decode($raw, true);
    if (json_last_error() === JSON_ERROR_NONE && is_array($j)) return $j;
  }
  return $_POST;
}

function fail($msg, $code=400){
  http_response_code($code);
  echo json_encode(['ok'=>false,'error'=>$msg]);
  exit;
}

/* เปิดโหมดโชว์ข้อผิดพลาด mysqli ระหว่างดีบั๊ก (ถ้าโปรดักชันค่อยปิด) */
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

$body   = read_input();
$action = $_GET['action'] ?? ($body['action'] ?? '');

try {
  /* ---- product_get ---- */
  if ($action === 'product_get' && $_SERVER['REQUEST_METHOD'] === 'GET') {
    $code = trim((string)($_GET['code'] ?? ''));
    if ($code === '') fail('Missing code');

    $stmt = $conn_product->prepare("SELECT code,name,price,stock,image,updated_at FROM products WHERE code=? LIMIT 1");
    $stmt->bind_param("s", $code);
    $stmt->execute();
    $res = $stmt->get_result();
    $p = $res->fetch_assoc();

    echo json_encode(['ok'=>true,'product'=>$p ?: null]); exit;
  }

  /* ---- item_save : สร้าง order + item และอัปเดตสต๊อก (transaction) ---- */
  if ($action === 'item_save' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    // รับค่าและ sanitize
    $code      = preg_replace('/\D+/', '', (string)($body['code'] ?? '')); // เก็บเฉพาะเลข
    $name      = trim((string)($body['name'] ?? ''));
    $qty       = max(0, (int)($body['qty'] ?? 0));
    $price     = (float)str_replace(',', '.', (string)($body['price'] ?? 0));
    $direction = strtolower(trim((string)($body['direction'] ?? 'in'))); // in | out
    $userId    = (int)($body['userId'] ?? 0);

    if ($code==='' || $name==='' || $qty<=0 || $price<=0) fail('Missing/invalid fields');

    // คำนวณ
    $lineTotal = $qty * $price;
    $subtotal  = $lineTotal;
    $vat       = round($subtotal * 0.07, 2);
    $total     = $subtotal + $vat;

    // เริ่มทรานแซกชัน
    $conn_product->begin_transaction();

    // 1) ให้แน่ใจว่ามีสินค้าใน products ก่อน (กัน FK พัง)
    $stmt = $conn_product->prepare("SELECT code FROM products WHERE code=? LIMIT 1");
    $stmt->bind_param("s", $code);
    $stmt->execute();
    $exists = (bool)$stmt->get_result()->fetch_row();

    if (!$exists) {
      $zero = 0;
      $img  = null;
      $stmt = $conn_product->prepare("
        INSERT INTO products(code,name,price,stock,image,created_at,updated_at)
        VALUES(?,?,?,?,?,NOW(),NOW())
      ");
      $stmt->bind_param("ssdis", $code, $name, $price, $zero, $img);
      $stmt->execute();
    }

    // 2) สร้าง orders
    $dirForOrder = ($direction === 'out') ? 'out' : 'in';
    $stmt = $conn_product->prepare("
      INSERT INTO orders(subtotal,vat,total,direction,created_by)
      VALUES (?,?,?,?,?)
    ");
    $stmt->bind_param("dddsi", $subtotal, $vat, $total, $dirForOrder, $userId);
    $stmt->execute();
    $orderId = (int)$stmt->insert_id;

    // 3) สร้าง order_items (ใช้ product_code ให้ตรง FK)
    $stmt = $conn_product->prepare("
      INSERT INTO order_items(order_id, code, name, product_code, qty, price, line_total, created_at, direction)
      VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), ?)
    ");
    $dirForItem = $dirForOrder; // เก็บไว้ดูทิศทางในรายการ
    $stmt->bind_param("isssidds", $orderId, $code, $name, $code, $qty, $price, $lineTotal, $dirForItem);
    $stmt->execute();

    // 4) อัปเดต stock (+/- ตาม direction) และไม่ให้ต่ำกว่า 0
    if ($direction === 'out') {
      $stmt = $conn_product->prepare("
        UPDATE products
        SET stock = GREATEST(0, stock - ?), updated_at = NOW()
        WHERE code = ?
      ");
    } else {
      $stmt = $conn_product->prepare("
        UPDATE products
        SET stock = stock + ?, updated_at = NOW()
        WHERE code = ?
      ");
    }
    $stmt->bind_param("is", $qty, $code);
    $stmt->execute();

    // เสร็จปกติ
    $conn_product->commit();
    echo json_encode(['ok'=>true,'orderId'=>$orderId]); exit;
  }

  /* ---- product_upsert (ออปชัน: อัปเดตรูป/ชื่อ/ราคา แบบไม่ยุ่ง stock) ---- */
  if ($action === 'product_upsert' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $code  = preg_replace('/\D+/', '', (string)($body['code'] ?? ''));
    $name  = trim((string)($body['name'] ?? ''));
    $price = (float)($body['price'] ?? 0);
    $image = (string)($body['image'] ?? '');

    if ($code==='' || $name==='') fail('Missing code/name');

    $stmt = $conn_product->prepare("
      INSERT INTO products(code,name,price,stock,image,created_at,updated_at)
      VALUES(?,?,?,?,?,NOW(),NOW())
      ON DUPLICATE KEY UPDATE
        name=VALUES(name),
        price=VALUES(price),
        image=VALUES(image),
        updated_at=VALUES(updated_at)
    ");
    $zero = 0;
    $stmt->bind_param("ssdis", $code, $name, $price, $zero, $image);
    $stmt->execute();

    echo json_encode(['ok'=>true]); exit;
  }

  // ไม่ตรง action
  http_response_code(404);
  echo json_encode(['ok'=>false,'error'=>'unknown action']); exit;

} catch (Throwable $e) {
  // rollback ถ้ามี transaction ค้าง
  if ($conn_product->errno === 0) {
    // best-effort
    @mysqli_rollback($conn_product);
  }
  http_response_code(500);
  echo json_encode(['ok'=>false,'error'=>'server error','detail'=>$e->getMessage()]);
}