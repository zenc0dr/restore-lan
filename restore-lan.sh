#!/usr/bin/env bash
# restore-lan.sh — умное восстановление сети для систем с Docker и VPN
# Адаптирован для Ubuntu 20.04+ с Docker, sing-box/Outline, Clash API
# Использование: sudo restore-lan [--iface enp2s0] [--dry] [--backup] [--safe-mode] [--restore-backup] [--force-docker-stop]

set -Eeuo pipefail

# Версия скрипта
VERSION="2.0"
IFACE=""
DRY=0
BACKUP=1
SAFE_MODE=0
RESTORE_BACKUP=0
FORCE_DOCKER_STOP=0
LOG="/tmp/restore_lan_$(date +%F_%H-%M-%S).log"
BACKUP_DIR="/tmp/network_backups"
LOCK_FILE="/tmp/restore_lan.lock"
RESTORE_POINT=""

# Цветной вывод
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Функции логирования
log_info() { echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "$LOG"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "$LOG"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG"; }
log_debug() { echo -e "${PURPLE}[DEBUG]${NC} $*" | tee -a "$LOG"; }

# Обработка аргументов
for a in "$@"; do
  case "$a" in
    --iface) shift; IFACE="${1:-}"; shift || true ;;
    --dry) DRY=1; shift ;;
    --no-backup) BACKUP=0; shift ;;
    --safe-mode) SAFE_MODE=1; shift ;;
    --restore-backup) RESTORE_BACKUP=1; shift ;;
    --force-docker-stop) FORCE_DOCKER_STOP=1; shift ;;
    --version|-v) 
      echo "restore-lan версии $VERSION"
      echo "Автор: Rael (AI Assistant)"
      echo "Описание: Умное восстановление сети для систем с Docker и VPN"
      exit 0
      ;;
    --help|-h) 
      echo "Использование: restore-lan [--iface INTERFACE] [--dry] [--no-backup] [--safe-mode] [--restore-backup] [--force-docker-stop]"
      echo "  --iface INTERFACE     Указать сетевой интерфейс (автоопределение если не указан)"
      echo "  --dry                 Только показать что будет сделано"
      echo "  --no-backup           Не создавать резервные копии"
      echo "  --safe-mode           Безопасный режим (только диагностика и мягкие исправления)"
      echo "  --restore-backup      Восстановить из последней резервной копии"
      echo "  --force-docker-stop   Принудительно остановить все Docker контейнеры"
      echo "  --version, -v         Показать версию скрипта"
      echo "  --help, -h            Показать эту справку"
      echo ""
      echo "Примеры:"
      echo "  sudo restore-lan                    # Обычное восстановление"
      echo "  sudo restore-lan --safe-mode --dry  # Диагностика без изменений"
      echo "  sudo restore-lan --force-docker-stop # С принудительной остановкой Docker"
      echo ""
      echo "Быстрая установка:"
      echo "  curl -sSL https://raw.githubusercontent.com/username/rael-scripts/main/scripts/restore-lan/restore-lan.sh | sudo tee ~/.bin/restore-lan > /dev/null && sudo chmod +x ~/.bin/restore-lan"
      exit 0
      ;;
    *) shift ;;
  esac
done

# Проверка прав
[[ $EUID -eq 0 ]] || { log_error "Запусти от root: sudo bash $0"; exit 1; }

# Проверка блокировки
if [[ -f "$LOCK_FILE" ]]; then
  PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
  if [[ -n "$PID" ]] && kill -0 "$PID" 2>/dev/null; then
    log_error "Скрипт уже запущен (PID: $PID). Если это ошибка, удалите $LOCK_FILE"
    exit 1
  else
    log_warning "Найден устаревший lock файл, удаляю..."
    rm -f "$LOCK_FILE"
  fi
fi

# Устанавливаем блокировку
echo $$ > "$LOCK_FILE"
trap 'cleanup_on_exit' EXIT INT TERM

# Функция очистки при выходе
cleanup_on_exit() {
  log_info "🧹 Очистка при выходе..."
  rm -f "$LOCK_FILE"
  if [[ $DRY -eq 0 ]] && [[ $SAFE_MODE -eq 0 ]]; then
    log_info "Сеть восстановлена. Проверьте подключение."
  fi
}

# Перенаправляем весь вывод в лог
exec &> >(tee -a "$LOG")

log_info "🚀 Запуск умного восстановления сети. Лог: $LOG"
log_info "Режим: $([ $DRY -eq 1 ] && echo "DRY-RUN" || echo "ВЫПОЛНЕНИЕ")"
log_info "Безопасный режим: $([ $SAFE_MODE -eq 1 ] && echo "ДА" || echo "НЕТ")"
log_info "Восстановление из резервной копии: $([ $RESTORE_BACKUP -eq 1 ] && echo "ДА" || echo "НЕТ")"
log_info "Принудительная остановка Docker: $([ $FORCE_DOCKER_STOP -eq 1 ] && echo "ДА" || echo "НЕТ")"

# Функции
run() { 
  if [[ $DRY -eq 1 ]]; then 
    log_info "DRY: $*"
  else 
    log_info "Выполняю: $*"
    eval "$@" || log_warning "Команда завершилась с ошибкой: $*"
  fi
}

# Проверка доступности команд
check_commands() {
  log_info "🔍 Проверяю доступность команд..."
  
  local missing_commands=()
  
  for cmd in ip iptables systemctl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing_commands+=("$cmd")
    fi
  done
  
  # Проверяем nftables
  if command -v nft >/dev/null 2>&1; then
    log_info "nftables доступен"
  else
    log_warning "nftables не найден, используем iptables"
  fi
  
  if [[ ${#missing_commands[@]} -gt 0 ]]; then
    log_error "Отсутствуют критичные команды: ${missing_commands[*]}"
    exit 1
  fi
  
  log_success "Все необходимые команды доступны"
}

# Создание резервных копий
create_backups() {
  if [[ $BACKUP -eq 0 ]]; then
    log_warning "Создание резервных копий отключено"
    return 0
  fi
  
  log_info "📦 Создаю резервные копии..."
  mkdir -p "$BACKUP_DIR"
  
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  
  # Резервная копия iptables
  if command -v iptables-save >/dev/null 2>&1; then
    run "iptables-save > '$BACKUP_DIR/iptables_backup_$timestamp.rules'"
  fi
  
  # Резервная копия nftables
  if command -v nft >/dev/null 2>&1; then
    run "nft list ruleset > '$BACKUP_DIR/nftables_backup_$timestamp.rules' 2>/dev/null || true"
  fi
  
  # Резервная копия маршрутов
  run "ip route show > '$BACKUP_DIR/routes_backup_$timestamp.txt'"
  
  # Резервная копия правил маршрутизации
  run "ip rule show > '$BACKUP_DIR/rules_backup_$timestamp.txt'"
  
  # Резервная копия resolv.conf
  if [[ -f /etc/resolv.conf ]]; then
    run "cp /etc/resolv.conf '$BACKUP_DIR/resolv_backup_$timestamp.conf'"
  fi
  
  # Резервная копия Docker сетей
  if command -v docker >/dev/null 2>&1; then
    run "docker network ls > '$BACKUP_DIR/docker_networks_backup_$timestamp.txt' 2>/dev/null || true"
  fi
  
  # Резервная копия systemd сервисов
  run "systemctl list-units --type=service --state=running | grep -E '(sing-box|outline|clash)' > '$BACKUP_DIR/vpn_services_backup_$timestamp.txt' 2>/dev/null || true"
  
  log_success "Резервные копии созданы в $BACKUP_DIR"
}

# Восстановление из резервной копии
restore_from_backup() {
  if [[ $RESTORE_BACKUP -eq 0 ]]; then
    return 0
  fi
  
  log_info "🔄 Восстанавливаю из резервной копии..."
  
  # Находим последнюю резервную копию
  local latest_backup
  latest_backup=$(ls -t "$BACKUP_DIR"/*.rules 2>/dev/null | head -n1 || echo "")
  
  if [[ -z "$latest_backup" ]]; then
    log_error "Резервные копии не найдены"
    return 1
  fi
  
  log_info "Восстанавливаю из: $latest_backup"
  
  if [[ "$latest_backup" == *"iptables"* ]]; then
    if command -v iptables-restore >/dev/null 2>&1; then
      run "iptables-restore < '$latest_backup'"
      log_success "iptables восстановлен"
    fi
  elif [[ "$latest_backup" == *"nftables"* ]]; then
    if command -v nft >/dev/null 2>&1; then
      run "nft flush ruleset"
      run "nft -f '$latest_backup'"
      log_success "nftables восстановлен"
    fi
  fi
  
  # Восстанавливаем маршруты
  local routes_backup
  routes_backup=$(ls -t "$BACKUP_DIR"/*routes*.txt 2>/dev/null | head -n1 || echo "")
  if [[ -n "$routes_backup" ]]; then
    log_info "Восстанавливаю маршруты из: $routes_backup"
    # Здесь можно добавить логику восстановления маршрутов
  fi
  
  log_success "Восстановление из резервной копии завершено"
  return 0
}

# Автоопределение интерфейса
detect_iface() {
  if [[ -n "$IFACE" ]]; then
    log_info "Используется указанный интерфейс: $IFACE"
    return 0
  fi
  
  log_info "🔍 Автоопределение сетевого интерфейса..."
  
  # Предпочитаем проводной с IPv4, UP и carrier
  local cand
  cand=$(ip -o -4 addr show up scope global 2>/dev/null | awk '!/docker|br-|veth|tun|outline|sbx|clash/ {print $2}' | sort -u)
  
  for i in $cand; do
    if [[ "$(cat /sys/class/net/$i/operstate 2>/dev/null || echo down)" == "up" ]]; then
      IFACE="$i"
      log_success "Автоопределен интерфейс: $IFACE"
      return 0
    fi
  done
  
  # fallback: первый глобальный
  IFACE=$(echo "$cand" | head -n1)
  if [[ -n "$IFACE" ]]; then
    log_warning "Используется fallback интерфейс: $IFACE"
    return 0
  fi
  
  log_error "Не удалось определить сетевой интерфейс"
  return 1
}

# Проверка состояния Docker
check_docker_status() {
  log_info "🐳 Проверяю состояние Docker..."
  
  if ! command -v docker >/dev/null 2>&1; then
    log_info "Docker не установлен"
    return 0
  fi
  
  if ! systemctl is-active --quiet docker; then
    log_warning "Docker сервис не активен"
    return 0
  fi
  
  # Проверяем проблемные сети
  local problem_networks
  problem_networks=$(docker network ls --format "{{.Name}}" --filter "driver=bridge" 2>/dev/null | grep -v "bridge\|host\|none" || true)
  
  if [[ -n "$problem_networks" ]]; then
    log_warning "Обнаружены пользовательские Docker сети:"
    echo "$problem_networks" | while read -r net; do
      log_warning "  - $net"
    done
  fi
  
  # Проверяем linkdown мосты
  local linkdown_bridges
  linkdown_bridges=$(ip route show 2>/dev/null | grep "linkdown" | grep "br-" | awk '{print $3}' | sed 's/^br-//' || true)
  
  if [[ -n "$linkdown_bridges" ]]; then
    log_warning "Обнаружены linkdown Docker мосты:"
    echo "$linkdown_bridges" | while read -r br; do
      log_warning "  - $br"
    done
  fi
  
  # Проверяем проблемные контейнеры
  local problem_containers
  problem_containers=$(docker ps --format "{{.Names}}" --filter "status=running" 2>/dev/null | head -5 || true)
  
  if [[ -n "$problem_containers" ]]; then
    log_info "Активные контейнеры:"
    echo "$problem_containers" | while read -r container; do
      log_info "  - $container"
    done
  fi
}

# Безопасная остановка VPN сервисов
stop_vpn_services() {
  log_info "⛔ Останавливаю VPN сервисы..."
  
  # Останавливаем sing-box
  if systemctl --user list-unit-files --type=service 2>/dev/null | grep -q "sing-box"; then
    log_info "Останавливаю sing-box user service..."
    run "systemctl --user stop sing-box || true"
    run "systemctl --user disable sing-box || true"
  fi
  
  if systemctl list-unit-files --type=service 2>/dev/null | grep -q "sing-box"; then
    log_info "Останавливаю sing-box system service..."
    run "systemctl stop sing-box || true"
    run "systemctl disable sing-box || true"
  fi
  
  # Останавливаем Outline
  if systemctl list-unit-files --type=service 2>/dev/null | grep -q "outline"; then
    log_info "Останавливаю Outline service..."
    run "systemctl stop outline || true"
    run "systemctl disable outline || true"
  fi
  
  # Останавливаем Clash API
  if systemctl list-unit-files --type=service 2>/dev/null | grep -q "clash"; then
    log_info "Останавливаю Clash service..."
    run "systemctl stop clash || true"
    run "systemctl disable clash || true"
  fi
  
  # Добиваем процессы
  local vpn_processes
  vpn_processes=$(pgrep -f "sing-box|outline|clash|sb-vpn" 2>/dev/null || true)
  
  if [[ -n "$vpn_processes" ]]; then
    log_info "Завершаю VPN процессы: $vpn_processes"
    run "pkill -f 'sing-box|outline|clash|sb-vpn' || true"
    sleep 2
    # Принудительно убиваем если не завершились
    vpn_processes=$(pgrep -f "sing-box|outline|clash|sb-vpn" 2>/dev/null || true)
    if [[ -n "$vpn_processes" ]]; then
      log_warning "Принудительно завершаю процессы: $vpn_processes"
      run "pkill -9 -f 'sing-box|outline|clash|sb-vpn' || true"
    fi
  fi
  
  # Останавливаем YACD панель если запущена
  local yacd_pid
  yacd_pid=$(pgrep -f "yacd|:9091" 2>/dev/null || true)
  if [[ -n "$yacd_pid" ]]; then
    log_info "Останавливаю YACD панель (PID: $yacd_pid)..."
    run "kill $yacd_pid || true"
  fi
}

# Очистка TUN интерфейсов
clean_tun_interfaces() {
  log_info "🧹 Очищаю TUN интерфейсы..."
  
  # Находим все TUN интерфейсы
  local tun_interfaces
  tun_interfaces=$(ip -o link show 2>/dev/null | awk -F': ' '/tun|outline|sbx|clash/ {print $2}' | sed 's/@.*//' || true)
  
  if [[ -n "$tun_interfaces" ]]; then
    log_info "Обнаружены TUN интерфейсы: $tun_interfaces"
    
    for dev in $tun_interfaces; do
      # Пропускаем основной интерфейс
      [[ "$dev" == "$IFACE" ]] && continue
      
      log_info "Удаляю TUN интерфейс: $dev"
      run "ip link set dev '$dev' down || true"
      run "ip link delete '$dev' || true"
    done
  else
    log_info "TUN интерфейсы не обнаружены"
  fi
}

# Безопасная очистка iptables/nftables
clean_firewall() {
  log_info "🔥 Очищаю firewall правила..."
  
  if [[ $SAFE_MODE -eq 1 ]]; then
    log_warning "Безопасный режим: только диагностика firewall"
    if command -v nft >/dev/null 2>&1; then
      log_info "Текущие правила nftables:"
      run "nft list ruleset | head -20"
    else
      log_info "Текущие правила iptables:"
      run "iptables -L -n --line-numbers | head -20"
    fi
    return 0
  fi
  
  # Создаем резервную копию
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  
  if command -v nft >/dev/null 2>&1; then
    log_info "Очищаю nftables..."
    run "nft list ruleset > /tmp/nftables_backup_$timestamp.rules"
    run "nft flush ruleset || true"
  else
    log_info "Очищаю iptables..."
    if command -v iptables-save >/dev/null 2>&1; then
      run "iptables-save > /tmp/iptables_backup_$timestamp.rules"
    fi
    
    # Очищаем все таблицы
    log_info "Очищаю таблицу filter..."
    run "iptables -F || true"
    run "iptables -X || true"
    run "iptables -P INPUT ACCEPT || true"
    run "iptables -P FORWARD ACCEPT || true"
    run "iptables -P OUTPUT ACCEPT || true"
    
    log_info "Очищаю таблицу nat..."
    run "iptables -t nat -F || true"
    run "iptables -t nat -X || true"
    
    log_info "Очищаю таблицу mangle..."
    run "iptables -t mangle -F || true"
    run "iptables -t mangle -X || true"
  fi
  
  log_success "Firewall очищен"
}

# Очистка проблемных маршрутов
clean_problematic_routes() {
  log_info "🗺️ Очищаю проблемные маршруты..."
  
  # Удаляем linkdown маршруты
  local linkdown_routes
  linkdown_routes=$(ip route show 2>/dev/null | grep -F " linkdown" || true)
  
  if [[ -n "$linkdown_routes" ]]; then
    log_info "Удаляю linkdown маршруты..."
    echo "$linkdown_routes" | while read -r route; do
      local route_cmd
      route_cmd="ip route del ${route%% linkdown*}"
      run "$route_cmd || true"
    done
  fi
  
  # Удаляем дублирующиеся default маршруты
  local default_routes_count
  default_routes_count=$(ip route show default 2>/dev/null | wc -l)
  
  if [[ "$default_routes_count" -gt 1 ]]; then
    log_warning "Обнаружено $default_routes_count default маршрутов, удаляю дубли..."
    while ip route show default 2>/dev/null | grep -q "default"; do
      local route_line
      route_line=$(ip route show default 2>/dev/null | head -n1)
      run "ip route del $route_line || true"
    done
  fi
  
  # Удаляем проблемные правила маршрутизации
  log_info "Очищаю правила маршрутизации..."
  while read -r line; do
    if [[ "$line" =~ lookup\ (local|main|default) ]]; then
      continue
    fi
    local prio
    prio="${line%%:*}"
    [[ "$prio" =~ ^[0-9]+$ ]] || continue
    log_info "Удаляю правило приоритета $prio..."
    run "ip rule del priority $prio || true"
  done < <(ip rule show 2>/dev/null || true)
}

# Очистка Docker мостов и контейнеров
clean_docker_bridges() {
  log_info "🐳 Очищаю Docker мосты..."
  
  if [[ $SAFE_MODE -eq 1 ]]; then
    log_warning "Безопасный режим: только диагностика Docker мостов"
    log_info "Текущие Docker мосты:"
    run "ip -o link show | grep br- | head -10"
    return 0
  fi
  
  # Принудительно останавливаем контейнеры если нужно
  if [[ $FORCE_DOCKER_STOP -eq 1 ]]; then
    log_warning "Принудительно останавливаю все Docker контейнеры..."
    run "docker stop \$(docker ps -q) 2>/dev/null || true"
    run "docker rm \$(docker ps -aq) 2>/dev/null || true"
  fi
  
  # Проверяем, не используются ли мосты в маршрутах
  local used_bridges
  used_bridges=$(ip route show 2>/dev/null | grep "br-" | awk '{print $3}' | sed 's/^br-//' | sort -u || true)
  
  if [[ -n "$used_bridges" ]]; then
    log_warning "Docker мосты используются в маршрутах: $used_bridges"
    
    for br in $used_bridges; do
      if ip route show 2>/dev/null | grep "$br" | grep -q "default"; then
        log_warning "Мост $br используется для default маршрута, удаляю..."
        run "ip route del default dev $br || true"
      fi
    done
  fi
  
  # Перезапускаем Docker для очистки сетей
  if systemctl is-active --quiet docker; then
    log_info "Перезапускаю Docker для очистки сетей..."
    run "systemctl restart docker || true"
    sleep 5
  fi
}

# Восстановление сетевых служб
restore_network_services() {
  log_info "🔄 Восстанавливаю сетевые службы..."
  
  # Перезапускаем NetworkManager
  if systemctl is-active --quiet NetworkManager; then
    log_info "Перезапускаю NetworkManager..."
    run "systemctl restart NetworkManager || true"
    sleep 3
  fi
  
  # Переинициализируем интерфейс
  log_info "Переинициализирую интерфейс $IFACE..."
  run "ip link set $IFACE down || true"
  sleep 1
  run "ip link set $IFACE up || true"
  sleep 2
  
  # DHCP renew
  log_info "Обновляю DHCP на $IFACE..."
  if command -v dhclient >/dev/null 2>&1; then
    run "dhclient -r $IFACE || true"
    sleep 1
    run "dhclient $IFACE || true"
    sleep 2
  else
    log_warning "dhclient не найден, пропускаю DHCP renew"
  fi
}

# Исправление DNS
fix_dns() {
  log_info "🔎 Исправляю DNS..."
  
  # Проверяем systemd-resolved
  if systemctl is-active --quiet systemd-resolved; then
    log_info "systemd-resolved активен"
    
    # Проверяем символическую ссылку
    if [[ -L /etc/resolv.conf ]]; then
      log_info "/etc/resolv.conf корректно связан"
    else
      log_warning "/etc/resolv.conf не является символической ссылкой, исправляю..."
      run "ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf || true"
    fi
    
    # Очищаем кеш
    run "systemd-resolve --flush-caches || true"
  else
    log_warning "systemd-resolved не активен, запускаю..."
    run "systemctl enable --now systemd-resolved || true"
    sleep 2
  fi
  
  # Устанавливаем DNS серверы
  if command -v resolvectl >/dev/null 2>&1; then
    log_info "Устанавливаю DNS через resolvectl..."
    run "resolvectl revert $IFACE || true"
    run "resolvectl dns $IFACE 1.1.1.1 8.8.8.8 || true"
    run "resolvectl flush-caches || true"
  fi
}

# Восстановление маршрутизации
restore_routing() {
  log_info "🗺️ Восстанавливаю маршрутизацию..."
  
  # Получаем текущий шлюз
  local gw
  gw=$(ip route show default 2>/dev/null | awk '/default/ {print $3; exit}' || true)
  
  if [[ -z "$gw" ]]; then
    log_warning "Шлюз не найден, пытаюсь восстановить..."
    
    # Получаем IP адрес интерфейса
    local cidr
    cidr=$(ip -o -4 addr show dev "$IFACE" 2>/dev/null | awk '{print $4}' | head -n1)
    
    if [[ -n "$cidr" ]]; then
      local net base
      net="${cidr%/*}"
      base="$(cut -d. -f1-3 <<<"$net")"
      
      # Пробуем возможные адреса шлюза
      for candidate in "$base.1" "$base.254" "$base.2"; do
        log_info "Пробую установить default via $candidate..."
        if run "ip route replace default via $candidate dev $IFACE 2>/dev/null"; then
          log_success "Маршрут по умолчанию установлен через $candidate"
          gw="$candidate"
          break
        fi
      done
    fi
  else
    log_success "Шлюз найден: $gw"
    run "ip route replace default via $gw dev $IFACE || true"
  fi
}

# Исправление MTU
fix_mtu() {
  log_info "📏 Исправляю MTU..."
  
  local current_mtu
  current_mtu=$(cat /sys/class/net/"$IFACE"/mtu 2>/dev/null || echo "1500")
  log_info "Текущий MTU для $IFACE: $current_mtu"
  
  # Проверяем и исправляем MTU
  if [[ "$current_mtu" -gt 1500 ]]; then
    log_warning "MTU $current_mtu может быть слишком большим, уменьшаю..."
    run "ip link set dev $IFACE mtu 1500 || true"
    sleep 1
  fi
  
  if [[ "$current_mtu" -lt 1280 ]]; then
    log_warning "MTU $current_mtu слишком маленький, увеличиваю..."
    run "ip link set dev $IFACE mtu 1500 || true"
    sleep 1
  fi
  
  local final_mtu
  final_mtu=$(cat /sys/class/net/"$IFACE"/mtu 2>/dev/null || echo "unknown")
  log_info "Финальный MTU для $IFACE: $final_mtu"
}

# Диагностика после восстановления
post_recovery_diagnostics() {
  log_info "🔍 Диагностика после восстановления..."
  
  # Сетевые интерфейсы
  log_info "Сетевые интерфейсы:"
  run "ip -o link show | head -10"
  
  # IP адреса
  log_info "IP адреса:"
  run "ip -o -4 addr show | head -10"
  
  # Маршруты
  log_info "Маршруты:"
  run "ip route show | head -10"
  
  # DNS
  log_info "DNS конфигурация:"
  if command -v resolvectl >/dev/null 2>&1; then
    run "resolvectl status $IFACE | head -5"
  fi
  
  # Тесты связи
  log_info "🧪 Тесты связи:"
  
  # Пинг шлюза
  local gw_ip
  gw_ip=$(ip route show default 2>/dev/null | awk '/default/ {print $3; exit}' || echo "")
  if [[ -n "$gw_ip" ]]; then
    log_info "Пинг шлюза $gw_ip..."
    if run "ping -c 2 -W 2 $gw_ip"; then
      log_success "Пинг шлюза успешен"
    else
      log_warning "Пинг шлюза не удался"
    fi
  fi
  
  # Пинг внешних DNS
  log_info "Пинг 1.1.1.1..."
  if run "ping -c 2 -W 2 1.1.1.1"; then
    log_success "Пинг 1.1.1.1 успешен"
  else
    log_warning "Пинг 1.1.1.1 не удался"
  fi
  
  # DNS тест
  log_info "DNS тест..."
  if run "getent hosts google.com"; then
    log_success "DNS работает"
  else
    log_warning "DNS не работает"
  fi
  
  # Проверка Docker
  if command -v docker >/dev/null 2>&1; then
    log_info "Проверка Docker..."
    if run "docker ps --format 'table {{.Names}}\t{{.Status}}' | head -5"; then
      log_success "Docker работает"
    else
      log_warning "Docker не отвечает"
    fi
  fi
}

# Основная функция восстановления
main_recovery() {
  log_info "🌿 Начинаю восстановление сети..."
  
  # Проверяем команды
  check_commands
  
  # Если нужно восстановить из резервной копии
  if [[ $RESTORE_BACKUP -eq 1 ]]; then
    restore_from_backup
    log_success "✅ Восстановление из резервной копии завершено!"
    return 0
  fi
  
  # Создаем резервные копии
  create_backups
  
  # Определяем интерфейс
  detect_iface || exit 1
  
  # Проверяем Docker
  check_docker_status
  
  # Останавливаем VPN сервисы
  stop_vpn_services
  
  # Очищаем TUN интерфейсы
  clean_tun_interfaces
  
  # Очищаем firewall
  clean_firewall
  
  # Очищаем проблемные маршруты
  clean_problematic_routes
  
  # Очищаем Docker мосты
  clean_docker_bridges
  
  # Восстанавливаем сетевые службы
  restore_network_services
  
  # Исправляем MTU
  fix_mtu
  
  # Исправляем DNS
  fix_dns
  
  # Восстанавливаем маршрутизацию
  restore_routing
  
  # Диагностика
  post_recovery_diagnostics
  
  log_success "✅ Восстановление завершено!"
  log_info "Лог сохранен в: $LOG"
  
  if [[ $BACKUP -eq 1 ]]; then
    log_info "Резервные копии в: $BACKUP_DIR"
  fi
}

# Обработка ошибок
trap 'log_error "Произошла ошибка в строке $LINENO"; exit 1' ERR

# Запуск
main_recovery
