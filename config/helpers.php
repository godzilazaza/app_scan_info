<?php
function cors()
{
    $origin = $_SERVER['HTTP_ORIGIN'] ?? '';
    $allowed = [
        'https://weerispost.online',
        'https://www.weerispost.online',
        'http://localhost:5173',
        'http://127.0.0.1:5173',
    ];
    if (in_array($origin, $allowed, true)) {
        header("Access-Control-Allow-Origin: $origin");
        header('Vary: Origin');
    }
    header('Access-Control-Allow-Credentials: true');
    header('Access-Control-Allow-Headers: Content-Type, Authorization');
    header('Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS');
    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        http_response_code(204);
        exit;
    }
}

function json_out($data, $status = 200)
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

function read_json()
{
    $raw = file_get_contents('php://input');
    $data = json_decode($raw, true);
    return is_array($data) ? $data : [];
}



// <?php
// // api/helpers.php
// function cors()
// {
//     header('Access-Control-Allow-Origin: https://weerispost.online');
//     header('Access-Control-Allow-Credentials: true');
//     header('Access-Control-Allow-Headers: Content-Type, Authorization');
//     header('Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS');
//     if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
//         http_response_code(204);
//         exit;
//     }
// }

// function json_out($data, $status = 200)
// {
//     http_response_code($status);
//     header('Content-Type: application/json; charset=utf-8');
//     echo json_encode($data, JSON_UNESCAPED_UNICODE);
//     exit;
// }

// function read_json()
// {
//     $raw = file_get_contents('php://input');
//     $data = json_decode($raw, true);
//     return is_array($data) ? $data : [];
// }