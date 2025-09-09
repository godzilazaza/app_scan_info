<?php
$DB_HOST = "localhost";
$DB_USER = "weeris_addProduct";
$DB_PASS = "weeris02";
$DB_NAME = "weeris_addProduct";

$conn_product = new mysqli($DB_HOST, $DB_USER, $DB_PASS, $DB_NAME);
if ($conn_product->connect_error) {
  http_response_code(500);
  header('Content-Type: application/json; charset=utf-8');
  die(json_encode(["error" => "DB_CONNECT_FAILED", "detail" => $conn_product->connect_error]));
}
$conn_product->set_charset("utf8mb4");



// <?php
// // api/config_product.php
// $DB_HOST = "localhost";
// $DB_USER = "weeris_addProduct";
// $DB_PASS = "weeris02";
// $DB_NAME = "weeris_addProduct";

// $conn_product = new mysqli($DB_HOST, $DB_USER, $DB_PASS, $DB_NAME);
// if ($conn_product->connect_error) {
//   http_response_code(500);
//   header('Content-Type: application/json; charset=utf-8');
//   die(json_encode(["error" => "DB_CONNECT_FAILED", "detail" => $conn_product->connect_error]));
// }
// $conn_product->set_charset("utf8mb4");