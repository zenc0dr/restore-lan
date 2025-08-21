# 📡 restore-lan.sh - Умное восстановление сети

## 🚀 Быстрая установка

### ⚡ Одна команда для установки (рекомендуется):
```bash
curl -sSL https://raw.githubusercontent.com/zenc0dr/restore-lan/main/install.sh | bash
```

### 🔧 Или установка скрипта напрямую:
```bash
curl -sSL https://raw.githubusercontent.com/zenc0dr/restore-lan/main/restore-lan.sh | sudo tee ~/.bin/restore-lan > /dev/null && sudo chmod +x ~/.bin/restore-lan
```

### 📁 Пошаговая установка:
```bash
# 1. Создаем папку для скриптов (если её нет)
mkdir -p ~/.bin

# 2. Скачиваем скрипт
curl -sSL https://raw.githubusercontent.com/zenc0dr/restore-lan/main/restore-lan.sh -o ~/.bin/restore-lan

# 3. Делаем исполняемым
chmod +x ~/.bin/restore-lan

# 4. Добавляем в PATH (если нужно)
echo 'export PATH="$HOME/.bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### ✅ Проверка установки:
```bash
restore-lan --help
```

## 📋 Описание

`restore-lan` - это интеллектуальный скрипт для восстановления сетевого подключения на системах с Docker и VPN (sing-box, Outline, Clash API). Скрипт автоматически диагностирует проблемы, создает резервные копии и восстанавливает работоспособность сети.

## 🎯 Назначение

Скрипт решает типичные проблемы:
- Потеря доступа к localhost и Docker из-за VPN
- Конфликты маршрутизации между Docker и VPN
- Проблемные TUN интерфейсы
- Зависшие Docker мосты
- Нарушенные правила iptables/nftables
- Проблемы с DNS и MTU

## 🚀 Быстрый старт

### Минимальный запуск:
```bash
sudo restore-lan
```

### Рекомендуемый первый запуск (диагностика):
```bash
sudo restore-lan --safe-mode --dry
```

## 📖 Полный синтаксис

```bash
sudo restore-lan [ОПЦИИ]
```

### Доступные опции:

| Опция | Описание | Пример |
|-------|----------|---------|
| `--iface INTERFACE` | Указать сетевой интерфейс | `--iface enp2s0` |
| `--dry` | Только показать что будет сделано | `--dry` |
| `--no-backup` | Не создавать резервные копии | `--no-backup` |
| `--safe-mode` | Безопасный режим (только диагностика) | `--safe-mode` |
| `--restore-backup` | Восстановить из последней резервной копии | `--restore-backup` |
| `--force-docker-stop` | Принудительно остановить все Docker контейнеры | `--force-docker-stop` |
| `--help` или `-h` | Показать справку | `--help` |

## 🔧 Примеры использования

### 1. **Диагностика без изменений**
```bash
# Только посмотреть что происходит
sudo restore-lan --safe-mode --dry
```

### 2. **Обычное восстановление**
```bash
# Стандартное восстановление с созданием резервных копий
sudo restore-lan
```

### 3. **Восстановление с принудительной остановкой Docker**
```bash
# Если Docker контейнеры блокируют сеть
sudo restore-lan --force-docker-stop
```

### 4. **Восстановление из резервной копии**
```bash
# Если что-то пошло не так
sudo restore-lan --restore-backup
```

### 5. **Восстановление конкретного интерфейса**
```bash
# Указать конкретный сетевой интерфейс
sudo restore-lan --iface enp2s0
```

### 6. **Быстрая очистка без резервных копий**
```bash
# Экстренное восстановление
sudo restore-lan --no-backup --force-docker-stop
```

## 📊 Что делает скрипт

### Этап 1: Подготовка
- ✅ Проверка прав доступа (root)
- ✅ Проверка блокировки (защита от повторного запуска)
- ✅ Проверка доступности команд
- ✅ Создание резервных копий

### Этап 2: Диагностика
- 🔍 Автоопределение сетевого интерфейса
- 🐳 Проверка состояния Docker
- 📡 Анализ VPN сервисов

### Этап 3: Очистка
- ⛔ Остановка VPN сервисов (sing-box, Outline, Clash)
- 🧹 Удаление TUN интерфейсов
- 🔥 Очистка firewall правил (iptables/nftables)
- 🗺️ Удаление проблемных маршрутов
- 🐳 Очистка Docker мостов

### Этап 4: Восстановление
- 🔄 Перезапуск сетевых служб
- 📏 Исправление MTU
- 🔎 Восстановление DNS
- 🗺️ Восстановление маршрутизации

### Этап 5: Проверка
- 🧪 Тесты связи (ping шлюза, DNS)
- 📊 Диагностика после восстановления
- 🐳 Проверка Docker

## 🛡️ Безопасность

### Автоматические резервные копии:
- `iptables/nftables` правила
- Сетевые маршруты
- Правила маршрутизации
- DNS конфигурация
- Docker сети
- VPN сервисы

### Защита от ошибок:
- Проверка блокировки
- Graceful обработка ошибок
- Автоматическая очистка при выходе
- Логирование всех действий

## 📁 Файлы и логи

### Логи:
- **Основной лог**: `/tmp/restore_lan_YYYY-MM-DD_HH-MM-SS.log`
- **Резервные копии**: `/tmp/network_backups/`

### Структура резервных копий:
```
/tmp/network_backups/
├── iptables_backup_YYYYMMDD_HHMMSS.rules
├── nftables_backup_YYYYMMDD_HHMMSS.rules
├── routes_backup_YYYYMMDD_HHMMSS.txt
├── rules_backup_YYYYMMDD_HHMMSS.txt
├── resolv_backup_YYYYMMDD_HHMMSS.conf
├── docker_networks_backup_YYYYMMDD_HHMMSS.txt
└── vpn_services_backup_YYYYMMDD_HHMMSS.txt
```

## ⚠️ Важные предупреждения

### ⚡ Требования:
- **Обязательно**: права root (`sudo`)
- **Рекомендуется**: резервные копии важных данных
- **Желательно**: стабильное подключение к интернету

### 🚨 Риски:
- Временная потеря сетевого подключения
- Остановка всех VPN сервисов
- Перезапуск Docker (может остановить контейнеры)

### 💡 Рекомендации:
1. **Всегда** сначала используйте `--dry` или `--safe-mode`
2. **Создавайте** резервные копии перед критичными изменениями
3. **Проверяйте** логи после выполнения
4. **Тестируйте** на тестовой системе перед продакшеном

## 🔍 Диагностика проблем

### Если скрипт не запускается:
```bash
# Проверка прав
ls -la ~/.bin/restore-lan

# Проверка блокировки
ls -la /tmp/restore_lan.lock

# Проверка зависимостей
which ip iptables systemctl
```

### Если сеть не восстановилась:
```bash
# Просмотр логов
tail -f /tmp/restore_lan_*.log

# Проверка резервных копий
ls -la /tmp/network_backups/

# Восстановление из резервной копии
sudo restore-lan --restore-backup
```

### Проверка состояния сети:
```bash
# Интерфейсы
ip link show

# Маршруты
ip route show

# DNS
resolvectl status

# Docker
docker ps
docker network ls
```

## 🎯 Типичные сценарии использования

### Сценарий 1: Потеря доступа к localhost
```bash
sudo restore-lan --safe-mode --dry
sudo restore-lan --force-docker-stop
```

### Сценарий 2: VPN блокирует Docker
```bash
sudo restore-lan --safe-mode
sudo restore-lan
```

### Сценарий 3: Экстренное восстановление
```bash
sudo restore-lan --no-backup --force-docker-stop
```

### Сценарий 4: Откат изменений
```bash
sudo restore-lan --restore-backup
```

## 🔧 Настройка и кастомизация

### Переменные окружения:
```bash
# Изменить директорию резервных копий
export BACKUP_DIR="/home/user/backups"

# Изменить уровень логирования
export LOG_LEVEL="DEBUG"
```

### Автоматизация:
```bash
# Добавить в crontab для автоматического восстановления
0 */6 * * * /usr/bin/sudo ~/.bin/restore-lan --safe-mode >> /var/log/network-recovery.log 2>&1
```

### Создание алиаса (опционально):
```bash
# Добавить в ~/.bashrc для удобства
echo 'alias restore-lan="sudo ~/.bin/restore-lan"' >> ~/.bashrc
source ~/.bashrc

# Теперь можно запускать без sudo
restore-lan --help
```

## 📞 Поддержка

### Если нужна помощь:
1. Проверьте логи: `/tmp/restore_lan_*.log`
2. Используйте `--safe-mode --dry` для диагностики
3. Создайте issue с описанием проблемы и логами

### Полезные команды для диагностики:
```bash
# Состояние сети
ip addr show
ip route show
ip rule show

# Состояние сервисов
systemctl status NetworkManager
systemctl status docker
systemctl --user status sing-box

# Docker сети
docker network ls
docker network inspect bridge

# VPN процессы
pgrep -f "sing-box|outline|clash"
```

## 🆘 Обновление скрипта

### Автоматическое обновление:
```bash
# Обновить до последней версии
curl -sSL https://raw.githubusercontent.com/zenc0dr/restore-lan/main/restore-lan.sh -o ~/.bin/restore-lan && chmod +x ~/.bin/restore-lan
```

### Проверка версии:
```bash
# Посмотреть текущую версию
restore-lan --version 2>/dev/null || echo "Версия не определена"
```

---

**⚠️ Внимание**: Этот скрипт изменяет сетевую конфигурацию системы. Всегда тестируйте на тестовой системе и создавайте резервные копии перед использованием в продакшене.

**📝 Автор**: Rael (AI Assistant)  
**🔄 Версия**: 2.0  
**📅 Обновлено**: 2024-12-19
