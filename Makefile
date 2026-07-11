.PHONY: help check-vagrant-plugins bloque1 bloque2 bloque3 bloque4 down1 down3 down4 destroy1 destroy3 destroy4 destroy-all

help:
	@echo "Comandos disponibles para el despliegue del TFG:"
	@echo "make bloque1     - Despliega el Bloque 1 (Secure App - Docker)"
	@echo "make bloque2     - Despliega el Bloque 2 (Vulnerable Apps - Pendiente)"
	@echo "make bloque3     - Despliega el Bloque 3 (Secure Network Lab - Vagrant)"
	@echo "make bloque4     - Despliega el Bloque 4 (Insecure Network Lab - Vagrant)"
	@echo ""
	@echo "Comandos de detención rápida (mantiene datos):"
	@echo "make down1       - Detiene los contenedores del Bloque 1"
	@echo "make down3       - Apaga las MVs del Bloque 3"
	@echo "make down4       - Apaga las MVs del Bloque 4"
	@echo ""
	@echo "Comandos de DESTRUCCIÓN TOTAL (Borrado de discos, BD e imágenes):"
	@echo "make destroy1    - Elimina contenedores, volúmenes, BD e imágenes de Docker"
	@echo "make destroy3    - Destruye las MVs y limpia metadatos de Vagrant (Bloque 3)"
	@echo "make destroy4    - Destruye las MVs y limpia metadatos de Vagrant (Bloque 4)"
	@echo "make destroy-all - Elimina todo los bloques, sus dependencias y archivos asociados"
	@echo "prune - Libera recursos"

check-vagrant-plugins:
	@vagrant plugin list | grep -q vagrant-none-communicator || vagrant plugin install vagrant-none-communicator

bloque1:
	@echo ""
	@echo "=================================================="
	@echo "Desplegando Bloque 1 — Secure App (Docker Compose)"
	@echo "=================================================="
	@if [ ! -f 1-secure-app/.env ]; then \
		echo "[+] Archivo .env no encontrado. Generando automáticamente desde .env.example..."; \
		cp 1-secure-app/.env.example 1-secure-app/.env; \
	fi
	@cd 1-secure-app && docker compose up -d --build
	@echo ""
	@echo "=================================================="
	@echo "¡Despliegue completado con éxito!"
	@echo "Portal web disponible en: https://localhost"
	@echo "=================================================="
	@echo ""

bloque2:
	@echo " [!] Módulo pendiente de integración técnica."

bloque3: check-vagrant-plugins
	@echo ""
	@echo "=================================================="
	@echo "Desplegando Bloque 3 — Secure Network Lab"
	@echo "=================================================="
	@cd 3-secure-network-lab && vagrant up
	@echo ""

bloque4: check-vagrant-plugins
	@echo ""
	@echo "=================================================="
	@echo "Desplegando Bloque 4 — Insecure Network Lab"
	@echo "=================================================="
	@cd 4-insecure-network-lab && vagrant up
	@echo ""

down1:
	@cd 1-secure-app && docker compose down

down3:
	@cd 3-secure-network-lab && vagrant halt

down4:
	@cd 4-insecure-network-lab && vagrant halt

destroy1:
	@echo ""
	@echo "[!] Destruyendo Bloque 1 (Contenedores, Volúmenes e Imágenes)..."
	@cd 1-secure-app && docker compose down -v --rmi all --remove-orphans
	@echo "[+] Bloque 1 purgado por completo."
	@echo ""

destroy3:
	@echo ""
	@echo "[!] Destruyendo Bloque 3 (Eliminando discos virtuales de VirtualBox)..."
	@-vagrant -C 3-secure-network-lab destroy -f 2>/dev/null || true
	@rm -rf 3-secure-network-lab/.vagrant/ 2>/dev/null || true
	@echo "[+] Bloque 3 purgado por completo."
	@echo ""

destroy4:
	@echo ""
	@echo "[!] Destruyendo Bloque 4 (Eliminando discos virtuales de VirtualBox)..."
	@cd 4-insecure-network-lab && vagrant destroy -f
	@rm -rf 4-insecure-network-lab/.vagrant/
	@echo "[+] Bloque 4 purgado por completo."
	@echo ""

destroy-all: destroy1 destroy3 destroy4
	@echo "=================================================="
	@echo "Todo limpio"
	@echo "=================================================="

prune:
	@echo ""
	@echo "[!] Purgando cachés e índices fantasmas..."
	@vagrant global-status --prune >/dev/null
	@-docker system prune -f >/dev/null 2>&1
	@echo "[!] Caza de brujas: Matando procesos VBoxHeadless colgados en RAM..."
	@-pkill -9 -f VBoxHeadless 2>/dev/null || true
	@-pkill -9 -f VBoxNetDHCP 2>/dev/null || true
	@echo "[+] Sistema optimizado y memoria RAM liberada."
	@echo ""
