function New-ClientCertificate {
  param([String]$username, [String]$basePath = ((Resolve-Parh .).Path))

  $env:OPENSSL_CONF=[System.IO.Path]::GetTempFileName()

  Set-Content -Path $env:OPENSSL_CONF -Value @"
  distinguished_name = req_distinguished_name
  [req_distinguished_name]
  [v3_req_client]
  extendedKeyUsage = clientAuth
  subjectAltName = otherName:1.3.6.1.4.1.311.20.2.3;UTF8:$username@localhost
"@

  $user_path = Join-Path $basePath user.pem
  $key_path = Join-Path $basePath key.pem
  $pfx_path = Join-Path $basePath user.pfx

  openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -out $user_path -outform PEM -keyout $key_path -subj "/CN=$username" -extensions v3_req_client 2>&1

  openssl pkcs12 -export -in $user_path -inkey $key_path -out $pfx_path -passout pass: 2>&1

  del $env:OPENSSL_CONF
}

function New-WinrmUserCertificateMapping {
  param([String]$issuer)
  $secure_pass = ConvertTo-SecureString $env:winrm_pass -AsPlainText -Force
  $cred = New-Object System.Management.Automation.PSCredential ($env:winrm_user, $secure_pass)
  New-Item -Path WSMan:\localhost\ClientCertificate -Subject "$env:winrm_user@localhost" -URI * -Issuer $issuer -Credential $cred -Force
}

Export-ModuleMember New-ClientCertificate, New-WinrmUserCertificateMapping