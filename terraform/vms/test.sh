#!/bin/bash

set -e  # Выход при ошибке

# === НАСТРОЙКИ ===
REPO_URL="https://github.com/kubernetes-sigs/kubespray.git"
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$BASE_DIR/kubespray"
VENV_DIR="$HOME/.venv/kubespray"
INVENTORY_DIR="$REPO_DIR/inventory/mycluster"
INVENTORY_FILE="$INVENTORY_DIR/inventory.ini"
TERRAFORM_OUTPUT="terraform_output.txt"
ANSIBLE_PLAYBOOK="cluster.yml"


# === ИЗВЛЕКАЕМ ВСЕ ВНЕШНИЕ IP-АДРЕСА ИЗ inventory.ini ===
echo "🔍 Извлекаем внешние IP-адреса из inventory.ini..."
EXTERNAL_IPS=$(grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$INVENTORY_FILE" | sort -u)

# === ОБНОВЛЯЕМ k8s-cluster.yml, ДОБАВЛЯЯ ВНЕШНИЕ IP ===
K8S_CLUSTER_YML="$INVENTORY_DIR/group_vars/k8s_cluster/k8s-cluster.yml"

echo "📌 Обновляем файл $K8S_CLUSTER_YML с внешними IP..."

# Удаляем старые значения `supplementary_addresses_in_ssl_keys`
sed -i '' '/supplementary_addresses_in_ssl_keys:/,/^$/d' "$K8S_CLUSTER_YML"

# Добавляем заголовок `supplementary_addresses_in_ssl_keys`
echo -e "\nsupplementary_addresses_in_ssl_keys:" >> "$K8S_CLUSTER_YML"

# Добавляем IP-адреса в `k8s-cluster.yml`
for IP in $EXTERNAL_IPS; do
    echo "  - \"$IP\"" >> "$K8S_CLUSTER_YML"
done