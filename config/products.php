<?php
require_once __DIR__ . '/helpers.php';
require_once __DIR__ . '/config_product.php';
cors();

$method = $_SERVER['REQUEST_METHOD'];

/* LIST / SEARCH (no SQL_CALC_FOUND_ROWS) */
if ($method === 'GET' && !isset($_GET['code'])) {
  $q      = trim($_GET['q'] ?? '');
  $limit  = min(100, max(1, intval($_GET['limit'] ?? 50)));
  $offset = max(0, intval($_GET['offset'] ?? 0));

  if ($q !== '') {
    $stmt = $conn_product->prepare(
      "SELECT code,name,price,stock,image,created_at,updated_at
       FROM products
       WHERE name LIKE CONCAT('%', ?, '%') OR code LIKE CONCAT('%', ?, '%')
       ORDER BY updated_at DESC
       LIMIT ? OFFSET ?"
    );
    $stmt->bind_param("ssii", $q, $q, $limit, $offset);

    $cnt = $conn_product->prepare(
      "SELECT COUNT(*) AS t
       FROM products
       WHERE name LIKE CONCAT('%', ?, '%') OR code LIKE CONCAT('%', ?, '%')"
    );
    $cnt->bind_param("ss", $q, $q);
  } else {
    $stmt = $conn_product->prepare(
      "SELECT code,name,price,stock,image,created_at,updated_at
       FROM products
       ORDER BY updated_at DESC
       LIMIT ? OFFSET ?"
    );
    $stmt->bind_param("ii", $limit, $offset);

    $cnt = $conn_product->prepare("SELECT COUNT(*) AS t FROM products");
  }

  $stmt->execute();
  $res   = $stmt->get_result();
  $items = $res->fetch_all(MYSQLI_ASSOC);

  $cnt->execute();
  $totalRes = $cnt->get_result();
  $totalRow = $totalRes->fetch_assoc();
  $total    = intval($totalRow['t'] ?? 0);

  json_out(["items" => $items, "total" => $total]);
}

/* GET ONE */
if ($method === 'GET' && isset($_GET['code'])) {
  $code = trim($_GET['code'] ?? '');
  if ($code === '') json_out(["error" => "INVALID_CODE"], 400);

  $stmt = $conn_product->prepare("SELECT * FROM products WHERE code=? LIMIT 1");
  $stmt->bind_param("s", $code);
  $stmt->execute();
  $res = $stmt->get_result();
  $p   = $res->fetch_assoc();
  if (!$p) json_out(["error" => "NOT_FOUND"], 404);
  json_out($p);
}

/* UPSERT (NO STOCK ADJUSTMENT) */
if ($method === 'POST') {
  $d        = read_json();
  $code     = trim((string)($d['code'] ?? ''));
  $name     = trim((string)($d['name'] ?? ''));
  $priceRaw = $d['price'] ?? null;
  $image    = isset($d['image']) && trim((string)$d['image']) !== '' ? (string)$d['image'] : null;

  if ($code === '')                       json_out(["error" => "INVALID_CODE"], 400);
  if ($name === '')                       json_out(["error" => "NAME_REQUIRED"], 400);
  if (!is_numeric($priceRaw) || $priceRaw <= 0)
                                          json_out(["error" => "INVALID_PRICE"], 400);

  $price = (float)$priceRaw;

  $stmt = $conn_product->prepare(
    "INSERT INTO products (code,name,price,stock,image,created_at,updated_at)
     VALUES (?,?,?,?,?,NOW(),NOW())
     ON DUPLICATE KEY UPDATE
       name       = VALUES(name),
       price      = VALUES(price),
       image      = COALESCE(VALUES(image), products.image),
       updated_at = NOW()"
  );
  $zero = 0; // stock เริ่มต้น 0 เมื่อเป็นการ insert ครั้งแรก
  $stmt->bind_param("ssdis", $code, $name, $price, $zero, $image);
  $stmt->execute();

  $stmt = $conn_product->prepare("SELECT * FROM products WHERE code=? LIMIT 1");
  $stmt->bind_param("s", $code);
  $stmt->execute();
  $res = $stmt->get_result();
  json_out($res->fetch_assoc());
}

/* DELETE */
if ($method === 'DELETE') {
  $code = trim($_GET['code'] ?? '');
  if ($code === '') json_out(["error" => "INVALID_CODE"], 400);

  $stmt = $conn_product->prepare("DELETE FROM products WHERE code=?");
  $stmt->bind_param("s", $code);
  $stmt->execute();
  json_out(["ok" => true]);
}

json_out(["error" => "METHOD_NOT_ALLOWED"], 405);