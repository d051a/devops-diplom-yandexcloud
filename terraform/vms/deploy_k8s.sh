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

# === ПАРАМЕТРЫ ВЕРСИИ KUBESPRAY ===
KUBESPRAY_VERSION="${1:-v2.27.0}"

# === ФУНКЦИЯ ПРОВЕРКИ ПРИЛОЖЕНИЙ ===
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# === ПРОВЕРЯЕМ НАЛИЧИЕ HOMEBREW ===
if ! check_command brew; then
    echo "⚠️ Homebrew не найден! Устанавливаем..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# === ПРОВЕРКА И УСТАНОВКА ЗАВИСИМОСТЕЙ ===
echo "🔍 Проверка зависимостей..."

if ! check_command git; then
    echo "⚙️ Устанавливаем Git..."
    brew install git
fi

if ! check_command python3; then
    echo "⚙️ Устанавливаем Python..."
    brew install python3
fi

if ! check_command terraform; then
    echo "⚙️ Устанавливаем Terraform..."
    brew install terraform
fi

if ! check_command ansible; then
    echo "⚙️ Устанавливаем Ansible..."
    brew install ansible
fi

# === СОЗДАЁМ И АКТИВИРУЕМ PYTHON VIRTUALENV ===
echo "🔧 Создание Python virtual environment..."
mkdir -p "$VENV_DIR"
python3.13 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

# === ОБНОВЛЕНИЕ pip, setuptools, wheel ===
echo "🔄 Обновление pip, setuptools, wheel..."
pip install --upgrade pip setuptools wheel

# === УСТАНОВКА ПОСЛЕДНЕЙ ДОСТУПНОЙ ВЕРСИИ ANSIBLE 9.x ===
echo "🔍 Проверяем последнюю доступную версию Ansible 9.x..."
AVAILABLE_ANSIBLE_VERSION=$(pip index versions ansible | grep -oE '9\.[0-9]+\.[0-9]+' | tail -n 1)

if [[ -z "$AVAILABLE_ANSIBLE_VERSION" ]]; then
    echo "❌ Не удалось найти Ansible 9.x, устанавливаем последнюю доступную..."
    pip install "ansible>=6.0,<7.0"
else
    echo "✅ Устанавливаем Ansible версии $AVAILABLE_ANSIBLE_VERSION..."
    pip install "ansible==$AVAILABLE_ANSIBLE_VERSION"
fi



# === СКАЧИВАЕМ REPO KUBESPRAY, ЕСЛИ ЕГО НЕТ ===
if [ ! -d "$REPO_DIR" ]; then
    echo "⬇️ Клонируем репозиторий Kubespray..."
    git clone "$REPO_URL" "$REPO_DIR"
else
    # Переключаемся на выбранную версию
    cd "$REPO_DIR"
    git fetch --all
    echo "🛠️ Переключаемся на версию Kubespray: $KUBESPRAY_VERSION..."
    git checkout "$KUBESPRAY_VERSION"
fi

cd "$REPO_DIR"



# === УСТАНОВКА ЗАВИСИМОСТЕЙ KUBESPRAY ===
echo "📦 Устанавливаем зависимости Kubespray..."
pip install -r requirements.txt --no-deps



# # === СОЗДАЁМ INVENTORY ДЛЯ ANSIBLE ===
# echo "📁 Создаём inventory..."
# rm -rf "$INVENTORY_DIR"
# mkdir -p "$INVENTORY_DIR"
# rm -rf "$INVENTORY_DIR"
# cp -rfp inventory/sample "$INVENTORY_DIR"

# # Копируем файл inventory.ini
# cp "$BASE_DIR/inventory.ini" "$INVENTORY_FILE"



# # === ИЗВЛЕКАЕМ ВСЕ ВНЕШНИЕ IP-АДРЕСА ИЗ inventory.ini ===
# echo "🔍 Извлекаем внешние IP-адреса из inventory.ini..."
# EXTERNAL_IPS=$(grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$INVENTORY_FILE" | sort -u)

# # === ОБНОВЛЯЕМ k8s-cluster.yml, ДОБАВЛЯЯ ВНЕШНИЕ IP ===
# K8S_CLUSTER_YML="$INVENTORY_DIR/group_vars/k8s_cluster/k8s-cluster.yml"

# echo "📌 Обновляем файл $K8S_CLUSTER_YML с внешними IP..."

# # Удаляем старые значения `supplementary_addresses_in_ssl_keys`
# sed -i '' '/supplementary_addresses_in_ssl_keys:/,/^$/d' "$K8S_CLUSTER_YML"

# # Добавляем заголовок `supplementary_addresses_in_ssl_keys`
# echo "supplementary_addresses_in_ssl_keys:" >> "$K8S_CLUSTER_YML"

# # Добавляем IP-адреса в `k8s-cluster.yml`
# for IP in $EXTERNAL_IPS; do
#     echo "  - \"$IP\"" >> "$K8S_CLUSTER_YML"
# done

# echo "✅ Внешние IP-адреса добавлены в k8s-cluster.yml!"



# === ЗАПУСК ANSIBLE-PLAYBOOK ===
echo "🚀 Запуск установки Kubernetes..."
ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_PLAYBOOK" -b -vvvvv

echo "✅ Kubernetes установлен! Проверка кластера:"
kubectl get nodes