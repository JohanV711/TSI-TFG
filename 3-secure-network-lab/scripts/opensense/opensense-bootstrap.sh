#!/bin/sh
# SCRIPT DE CONSTRUCCIÓN — solo se usó una vez para crear la box snl-opnsense
# No ejecutar directamente. La box ya está empaquetada en opnsense-25.1-lab.box

export ASSUME_ALWAYS_YES=yes
export IGNORE_OSVERSION=yes

# Forzar repositorio FreeBSD con HTTPS
mkdir -p /usr/local/etc/pkg/repos
cat <<'REPO' > /usr/local/etc/pkg/repos/FreeBSD.conf
FreeBSD: {
  url: "https://pkg.FreeBSD.org/${ABI}/quarterly",
  mirror_type: "http",
  enabled: yes
}
REPO

echo "==> Instalando dependencias base..."
pkg update -f || true
pkg install -y ca_root_nss curl || true

echo "==> Descargando opnsense-bootstrap..."
curl -sL \
  https://raw.githubusercontent.com/opnsense/update/master/src/bootstrap/opnsense-bootstrap.sh.in \
  -o /tmp/bootstrap.sh

if [ ! -s /tmp/bootstrap.sh ]; then
  curl -sL \
    https://raw.githubusercontent.com/opnsense/update/master/src/bootstrap/opnsense-bootstrap.sh \
    -o /tmp/bootstrap.sh
fi

chmod +x /tmp/bootstrap.sh
# ESCRIBIR config.xml ANTES del bootstrap
echo "==> Escribiendo config.xml antes del bootstrap..."
mkdir -p /conf

cat <<'EOF' > /conf/config.xml
<?xml version="1.0"?>
<system>
    <webgui>
      <protocol>https</protocol>
      <port>443</port>
      <interfaces>em4</interfaces>
    </webgui>
    <enablesshd>1</enablesshd>
    <sshdkeyonly>0</sshdkeyonly>
  </system>
<opnsense>
  <system>
    <hostname>opnsense</hostname>
    <domain>lab.local</domain>
    <timezone>Europe/Madrid</timezone>
    <language>en_US</language>
    <nextuid>2000</nextuid>
    <nextgid>2000</nextgid>
    <user>
      <name>root</name>
      <descr>System Administrator</descr>
      <scope>system</scope>
      <groupname>admins</groupname>
      <password>$2y$10$YRVoF966T9hvv.4W1h8tSOQbFnH13rGRLFPzQ1TIyp3e2WViqSWfq</password>
      <uid>0</uid>
    </user>
    <group>
      <name>admins</name>
      <description>System Administrators</description>
      <scope>system</scope>
      <gid>1999</gid>
      <member>0</member>
      <priv>page-all</priv>
    </group>
  </system>
  <interfaces>
    <wan>
      <enable>1</enable>
      <if>em1</if>
      <ipaddr>91.168.50.1</ipaddr>
      <subnet>24</subnet>
      <blockbogons>0</blockbogons>
      <blockpriv>0</blockpriv>
    </wan>
    <lan>
      <enable>1</enable>
      <if>em4</if>
      <ipaddr>192.168.56.10</ipaddr>
      <subnet>24</subnet>
    </lan>
  </interfaces>
  <firewall>
    <rule>
      <type>pass</type>
      <interface>lan</interface>
      <ipprotocol>inet</ipprotocol>
      <protocol>tcp</protocol>
      <source><any/></source>
      <destination><any/><port>443</port></destination>
      <descr>Permitir HTTPS gestion</descr>
    </rule>
    <rule>
      <type>pass</type>
      <interface>lan</interface>
      <ipprotocol>inet</ipprotocol>
      <protocol>tcp</protocol>
      <source><any/></source>
      <destination><any/><port>22</port></destination>
      <descr>Permitir SSH gestion</descr>
    </rule>
  </firewall>
</opnsense>
EOF

echo "==> Instalando OPNsense 25.1..."
sh /tmp/bootstrap.sh -r 25.1 -y

echo "==> Bootstrap completado."
echo "==> IMPORTANTE: Ejecuta 'vagrant reload opensense' para aplicar OPNsense."