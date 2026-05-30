#!/usr/bin/env bash
set -euo pipefail

echo "=== ANÁLISIS DE ESPACIO ==="
echo "Espacio libre:"
df -h ~ | tail -1

echo -e "\nTamaño de carpetas en ~/TFG:"
du -sh ~/TFG/* 2>/dev/null | sort -h

echo -e "\n=== CAJAS VAGRANT INSTALADAS ==="
vagrant box list

echo -e "\n=== VMs DE VIRTUALBOX ==="
VBoxManage list vms

echo -e "\n=== ARCHIVOS GRANDES (>100M) EN ~/TFG ==="
find ~/TFG -type f -size +100M -exec ls -lh {} \; 2>/dev/null || echo "No hay archivos >100M"

echo -e "\n=== ¿Continuar con limpieza? (s/n) ==="
read -r answer
if [[ "$answer" != "s" ]]; then
  echo "Cancelado."
  exit 0
fi

echo -e "\n=== LIMPIANDO ARCHIVOS TEMPORALES ==="
find ~/TFG -type f -name "*.log" -size +10M -delete
find ~/TFG -type f -name "*.tmp" -delete
find ~/TFG -type f -name "*.swp" -delete
find ~/TFG -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

echo -e "\n=== LIMPIANDO CACHE DE APT (dentro de VMs running) ==="
for vm in opensense external-kali dmz-server gestion-vm vlan20-server; do
  if vagrant status "$vm" 2>/dev/null | grep -q "running"; then
    echo "Limpiando $vm..."
    vagrant ssh "$vm" -- "sudo apt-get clean && sudo apt-get autoclean"
  fi
done

echo -e "\n=== ESPACIO LIBRE DESPUÉS ==="
df -h ~ | tail -1
echo "✅ Limpieza completada."