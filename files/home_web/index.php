<?php
$hostname = gethostname();
$client_ip = $_SERVER['REMOTE_ADDR'];
?>
<!DOCTYPE html>
<html>
<head>
<title>Home Web</title>
<style>
body { font-family: Arial, sans-serif; margin: 40px; }
h1 { color: #333; }
</style>
</head>
<body>
<h1>Welcome to home_web</h1>
<p><strong>Server Hostname:</strong> <?php echo $hostname; ?></p>
<p><strong>Your IP:</strong> <?php echo $client_ip; ?></p>
</body>
</html>
