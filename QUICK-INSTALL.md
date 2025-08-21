# ⚡ Быстрая установка restore-lan

## 🚀 Одна команда для установки:

```bash
curl -sSL https://raw.githubusercontent.com/username/rael-scripts/main/scripts/restore-lan/install.sh | bash
```

## 📋 Что произойдет:

1. ✅ Создастся папка `~/.bin` (если её нет)
2. ✅ Скачается скрипт `restore-lan`
3. ✅ Скрипт станет исполняемым
4. ✅ `~/.bin` добавится в PATH
5. ✅ Опционально создастся алиас для запуска без sudo

## 🎯 После установки:

```bash
# Показать справку
restore-lan --help

# Показать версию
restore-lan --version

# Диагностика сети (без изменений)
sudo restore-lan --safe-mode --dry

# Восстановление сети
sudo restore-lan
```

## 🔧 Если что-то пошло не так:

```bash
# Проверить установку
ls -la ~/.bin/restore-lan

# Перезапустить терминал или обновить PATH
source ~/.bashrc

# Установить вручную
mkdir -p ~/.bin
curl -sSL https://raw.githubusercontent.com/username/rael-scripts/main/scripts/restore-lan/restore-lan.sh -o ~/.bin/restore-lan
chmod +x ~/.bin/restore-lan
```

## 💡 Совет:

**Всегда** сначала используйте `--safe-mode --dry` для диагностики!

---

**📚 Полная документация**: [README.md](README.md)
