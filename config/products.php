<?php
require_once __DIR__ . '/helpers.php';
require_once __DIR__ . '/config_product.php';
cors();

$method = $_SERVER['REQUEST_METHOD'];

// GET /api/products.php?q=น้ำ&limit=50&offset=0
if ($method === 'GET' && !isset($_GET['code'])) {
  $q = $_GET['q'] ?? '';
  $limit = min(100, max(1, intval($_GET['limit'] ?? 50)));
  $offset = max(0, intval($_GET['offset'] ?? 0));

  if ($q !== '') {
    $stmt = $conn_product->prepare(
      "SELECT SQL_CALC_FOUND_ROWS code,name,price,stock,image,created_at,updated_at
       FROM products
       WHERE name LIKE CONCAT('%', ?, '%') OR code LIKE CONCAT('%', ?, '%')
       ORDER BY updated_at DESC
       LIMIT ? OFFSET ?"
    );
    $stmt->bind_param("ssii", $q, $q, $limit, $offset);
  } else {
    $stmt = $conn_product->prepare(
      "SELECT SQL_CALC_FOUND_ROWS code,name,price,stock,image,created_at,updated_at
       FROM products ORDER BY updated_at DESC LIMIT ? OFFSET ?"
    );
    $stmt->bind_param("ii", $limit, $offset);
  }
  $stmt->execute();
  $res = $stmt->get_result();
  $items = $res->fetch_all(MYSQLI_ASSOC);

  $totalRes = $conn_product->query("SELECT FOUND_ROWS() AS t");
  $total = intval($totalRes->fetch_assoc()['t'] ?? 0);

  json_out(["items" => $items, "total" => $total]);
}

// GET /api/products.php?code=EAN13
if ($method === 'GET' && isset($_GET['code'])) {
  $code = $_GET['code'];
  $stmt = $conn_product->prepare("SELECT * FROM products WHERE code=? LIMIT 1");
  $stmt->bind_param("s", $code);
  $stmt->execute();
  $res = $stmt->get_result();
  $p = $res->fetch_assoc();
  if (!$p) json_out(["error" => "NOT_FOUND"], 404);
  json_out($p);
}

// POST /api/products.php (upsert)
if ($method === 'POST') {
  $d = read_json();
  $code  = $d['code']  ?? '';
  $name  = $d['name']  ?? '';
  $price = $d['price'] ?? null;
  $stock = $d['stock'] ?? null;
  $image = $d['image'] ?? null;

  if (!preg_match('/^\d{13}$/', $code)) json_out(["error" => "INVALID_CODE"], 400);
  if (trim($name) === '') json_out(["error" => "NAME_REQUIRED"], 400);
  if (!is_numeric($price) || $price <= 0) json_out(["error" => "INVALID_PRICE"], 400);
  if (!is_numeric($stock) || $stock < 0) json_out(["error" => "INVALID_STOCK"], 400);

  $stmt = $conn_product->prepare(
    "INSERT INTO products (code,name,price,stock,image)
     VALUES (?,?,?,?,?)
     ON DUPLICATE KEY UPDATE name=VALUES(name), price=VALUES(price), stock=VALUES(stock), image=VALUES(image)"
  );
  $stmt->bind_param("ssdis", $code, $name, $price, $stock, $image);
  $stmt->execute();

  $stmt = $conn_product->prepare("SELECT * FROM products WHERE code=?");
  $stmt->bind_param("s", $code);
  $stmt->execute();
  $res = $stmt->get_result();
  json_out($res->fetch_assoc());
}

// DELETE /api/products.php?code=EAN13
if ($method === 'DELETE') {
  $code = $_GET['code'] ?? '';
  if (!preg_match('/^\d{13}$/', $code)) json_out(["error" => "INVALID_CODE"], 400);
  $stmt = $conn_product->prepare("DELETE FROM products WHERE code=?");
  $stmt->bind_param("s", $code);
  $stmt->execute();
  json_out(["ok" => true]);
}

json_out(["error" => "METHOD_NOT_ALLOWED"], 405);



// <?php
// require_once __DIR__ . '/helpers.php';
// require_once __DIR__ . '/config_product.php';
// cors();

// $method = $_SERVER['REQUEST_METHOD'];

// // GET /api/products.php?q=น้ำ&limit=50&offset=0  (ลิสต์/ค้นหา)
// if ($method === 'GET' && !isset($_GET['code'])) {
//   $q = isset($_GET['q']) ? trim($_GET['q']) : '';
//   $limit = min(100, max(1, intval($_GET['limit'] ?? 50)));
//   $offset = max(0, intval($_GET['offset'] ?? 0));

//   if ($q !== '') {
//     $stmt = $conn_product->prepare(
//       "SELECT SQL_CALC_FOUND_ROWS code,name,price,stock,image,created_at,updated_at
//        FROM products
//        WHERE name LIKE CONCAT('%', ?, '%') OR code LIKE CONCAT('%', ?, '%')
//        ORDER BY updated_at DESC
//        LIMIT ? OFFSET ?"
//     );
//     $stmt->bind_param("ssii", $q, $q, $limit, $offset);
//   } else {
//     $stmt = $conn_product->prepare(
//       "SELECT SQL_CALC_FOUND_ROWS code,name,price,stock,image,created_at,updated_at
//        FROM products ORDER BY updated_at DESC LIMIT ? OFFSET ?"
//     );
//     $stmt->bind_param("ii", $limit, $offset);
//   }
//   $stmt->execute();
//   $res = $stmt->get_result();
//   $items = $res->fetch_all(MYSQLI_ASSOC);

//   $totalRes = $conn_product->query("SELECT FOUND_ROWS() AS t");
//   $total = intval($totalRes->fetch_assoc()['t'] ?? 0);

//   json_out(["items" => $items, "total" => $total]);
// }

// // GET /api/products.php?code=EAN13  (หา 1 ชิ้นจากบาร์โค้ด)
// if ($method === 'GET' && isset($_GET['code'])) {
//   $code = $_GET['code'];
//   $stmt = $conn_product->prepare("SELECT * FROM products WHERE code=? LIMIT 1");
//   $stmt->bind_param("s", $code);
//   $stmt->execute();
//   $res = $stmt->get_result();
//   $p = $res->fetch_assoc();
//   if (!$p) json_out(["error" => "NOT_FOUND"], 404);
//   json_out($p);
// }

// // POST /api/products.php  (upsert: เพิ่มหรือแก้)
// // body: { code, name, price, stock, image? }  (image จะเป็น URL หรือ data:image;base64 ก็ได้)
// if ($method === 'POST') {
//   $d = read_json();
//   $code  = $d['code']  ?? '';
//   $name  = $d['name']  ?? '';
//   $price = $d['price'] ?? null;
//   $stock = $d['stock'] ?? null;
//   $image = $d['image'] ?? null;

//   if (!preg_match('/^\d{13}$/', $code)) json_out(["error" => "INVALID_CODE"], 400);
//   if (trim($name) === '') json_out(["error" => "NAME_REQUIRED"], 400);
//   if (!is_numeric($price) || $price <= 0) json_out(["error" => "INVALID_PRICE"], 400);
//   if (!is_numeric($stock) || $stock < 0) json_out(["error" => "INVALID_STOCK"], 400);

//   $stmt = $conn_product->prepare(
//     "INSERT INTO products (code,name,price,stock,image)
//      VALUES (?,?,?,?,?)
//      ON DUPLICATE KEY UPDATE name=VALUES(name), price=VALUES(price), stock=VALUES(stock), image=VALUES(image)"
//   );
//   $stmt->bind_param("ssdis", $code, $name, $price, $stock, $image);
//   $stmt->execute();

//   $stmt = $conn_product->prepare("SELECT * FROM products WHERE code=?");
//   $stmt->bind_param("s", $code);
//   $stmt->execute();
//   $res = $stmt->get_result();
//   json_out($res->fetch_assoc());
// }

// // DELETE /api/products.php?code=EAN13
// if ($method === 'DELETE') {
//   $code = $_GET['code'] ?? '';
//   if (!preg_match('/^\d{13}$/', $code)) json_out(["error" => "INVALID_CODE"], 400);
//   $stmt = $conn_product->prepare("DELETE FROM products WHERE code=?");
//   $stmt->bind_param("s", $code);
//   $stmt->execute();
//   json_out(["ok" => true]);
// }

// json_out(["error" => "METHOD_NOT_ALLOWED"], 405);