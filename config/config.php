<?php
// db.php
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

$host   = '127.0.0.1';          // ใช้ 127.0.0.1 แทน localhost เพื่อต่อ TCP ชัวร์
$user   = 'weeris_demo';        // จาก phpMyAdmin
$pass   = 'weeris02';           // จาก phpMyAdmin
$dbname = 'weeris_demoApp';     // ชื่อ DB ต้องตรงเป๊ะ (ตัวพิมพ์ใหญ่-เล็กสำคัญบนบางโฮสต์)
$port   = 3306;

try {
    $conn = new mysqli($host, $user, $pass, $dbname, $port);
    $conn->set_charset('utf8mb4');
    // ตั้ง timezone ให้ตรงไทย (ทางเลือก)
    $conn->query("SET time_zone = '+07:00'");
} catch (mysqli_sql_exception $e) {
    http_response_code(500);
    // หลีกเลี่ยงโชว์ข้อความละเอียดในโปรดักชัน
    echo "Connection failed";
    exit;
}
