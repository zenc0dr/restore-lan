#!/usr/bin/env bash
# install.sh - Быстрая установка restore-lan
# Использование: curl -sSL https://raw.githubusercontent.com/username/rael-scripts/main/scripts/restore-lan/install.sh | bash

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Функции
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# URL для скачивания
SCRIPT_URL="https://raw.githubusercontent.com/username/rael-scripts/main/scripts/restore-lan/restore-lan.sh"
INSTALL_DIR="$HOME/.bin"
SCRIPT_NAME="restore-lan"

log_info "🚀 Установка restore-lan..."

# Проверяем зависимости
if ! command -v curl >/dev/null 2>&1; then
    log_error "curl не найден. Установите curl и попробуйте снова."
    exit 1
fi

# Создаем директорию
log_info "📁 Создаю директорию $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"

# Скачиваем скрипт
log_info "⬇️ Скачиваю restore-lan..."
if curl -sSL "$SCRIPT_URL" -o "$INSTALL_DIR/$SCRIPT_NAME"; then
    log_success "Скрипт скачан успешно"
else
    log_error "Ошибка при скачивании скрипта"
    exit 1
fi

# Делаем исполняемым
log_info "🔧 Делаю скрипт исполняемым..."
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# Проверяем PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    log_info "📝 Добавляю $INSTALL_DIR в PATH..."
    
    # Определяем shell
    if [[ -n "$ZSH_VERSION" ]]; then
        SHELL_RC="$HOME/.zshrc"
    elif [[ -n "$BASH_VERSION" ]]; then
        SHELL_RC="$HOME/.bashrc"
    else
        SHELL_RC="$HOME/.profile"
    fi
    
    # Добавляем в PATH
    echo "" >> "$SHELL_RC"
    echo "# restore-lan PATH" >> "$SHELL_RC"
    echo 'export PATH="$HOME/.bin:$PATH"' >> "$SHELL_RC"
    
    log_success "PATH обновлен в $SHELL_RC"
    log_warning "Перезапустите терминал или выполните: source $SHELL_RC"
else
    log_success "PATH уже содержит $INSTALL_DIR"
fi

# Проверяем установку
log_info "✅ Проверяю установку..."
if "$INSTALL_DIR/$SCRIPT_NAME" --version >/dev/null 2>&1; then
    log_success "restore-lan установлен успешно!"
    echo ""
    echo "🎉 Установка завершена!"
    echo ""
    echo "Использование:"
    echo "  restore-lan --help                    # Показать справку"
    echo "  restore-lan --version                 # Показать версию"
    echo "  sudo restore-lan --safe-mode --dry    # Диагностика"
    echo "  sudo restore-lan                      # Восстановление сети"
    echo ""
    echo "📁 Скрипт установлен в: $INSTALL_DIR/$SCRIPT_NAME"
    echo "📚 Документация: https://github.com/username/rael-scripts/tree/main/scripts/restore-lan"
    echo ""
    echo "💡 Совет: Сначала используйте --safe-mode --dry для диагностики"
else
    log_error "Ошибка при проверке установки"
    exit 1
fi

# Создаем алиас для удобства (опционально)
read -p "🤔 Создать алиас 'restore-lan' для запуска без sudo? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [[ -n "$ZSH_VERSION" ]]; then
        echo 'alias restore-lan="sudo ~/.bin/restore-lan"' >> "$HOME/.zshrc"
        log_success "Алиас добавлен в ~/.zshrc"
    elif [[ -n "$BASH_VERSION" ]]; then
        echo 'alias restore-lan="sudo ~/.bin/restore-lan"' >> "$HOME/.bashrc"
        log_success "Алиас добавлен в ~/.bashrc"
    fi
    log_info "Перезапустите терминал или выполните: source $SHELL_RC"
fi

log_success "🎯 Установка завершена! Теперь можно использовать restore-lan"
