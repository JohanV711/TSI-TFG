# 1. Requisitos previos (solo una vez)
# Instalar VirtualBox 7.x desde https://virtualbox.org
# Instalar Vagrant 2.4.x desde https://vagrantup.com
# En Linux: sudo usermod -aG vboxusers $USER && newgrp vboxusers

# 2. Clonar el repositorio
git clone https://github.com/TU_USUARIO/TFG.git
cd TFG/3-secure-network-lab

# 3. Levantar el lab (descarga la box automáticamente ~1-2 GB)
vagrant up

# 4. Acceder a OPNsense WebUI
# Abrir túnel SSH:
ssh -L 8443:192.168.56.10:443 localhost -p 2222 -N
# Navegador: https://localhost:8443
# Usuario: root / Contraseña: opnsense