#!/usr/bin/env bash
set -euo pipefail

enforce_root(){
  if [[ $EUID -ne 0 ]]; then
    log error "This script must be run as root"
    exit 1
  fi
}

log() {
  local COLOR_NC='\e[0m'
  local COLOR_BOLD='\e[1m'
  local COLOR_DIM='\e[2m'
  local COLOR_ITALIC='\e[3m'

  case $1 in
    verbose | v )
      if [[ ${LOG_LEVEL} == verbose ]]; then
        local COLOR_VERBOSE='\e[95m'
        echo -e "* ${COLOR_VERBOSE}${COLOR_ITALIC}[VERBOSE] ${COLOR_DIM}${2}${COLOR_NC}"
      fi ;;
    debug | d )
      if [[ ${LOG_LEVEL} == verbose ]] || [[ ${LOG_LEVEL} == debug ]]; then
        local COLOR_DEBUG='\e[92m'
        echo -e "* ${COLOR_DEBUG}[DEBUG] ${COLOR_ITALIC}${COLOR_DIM}${2}${COLOR_NC}"
      fi ;;
    info | i )
      local COLOR_INFO='\e[34m'
      echo -e "* ${COLOR_INFO}[INFO] ${COLOR_DIM}${2}${COLOR_NC}"
      ;;
    warning | warn | w )
      local COLOR_WARN='\e[93m'
      echo -e "* ${COLOR_BOLD}[${COLOR_WARN}WARN${COLOR_NC}${COLOR_BOLD}] ${COLOR_WARN}${2}${COLOR_NC}"
      ;;
    error | err | e)
      local COLOR_ERR='\e[91m'
      echo -e "* ${COLOR_BOLD}[${COLOR_ERR}ERROR${COLOR_NC}${COLOR_BOLD}] ${COLOR_ERR}${2}${COLOR_NC}"
      echo ""
      ;;
    help | h)
      local COLOR_HELP='\e[34m'
      echo -e "${COLOR_HELP}${COLOR_DIM}* [HELP] ${COLOR_NC}${COLOR_HELP}${2}${COLOR_NC}"
      ;;
    * )
      echo -e "* [${1}${COLOR_NC}] ${2}"
      ;;
  esac
}

compare_versions() { [[ ! "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]]; }
# returns 0 if $2 is less than $1
# returns 1 if $2 is equal to or greater than $1

get_latest_ptero_release() {
  curl -s "https://cdn.pterodactyl.io/releases/latest.json" | # Get latest release from Pterodactyl releases.json
    grep '"${1}"' |                                                # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'                                    # Pluck JSON value
}

get_file_owner() { ls -ld ${1} | awk '{print $3}'; }
  # usage:
  # get_file_owner /var/www/pterodactyl
  # output: www-data

update_panel() {
  log debug "Updating the Panel!"
  cd ${PANEL_DIR}
  compare_versions 1.4.0 $INSTALLED_PANEL_VERSION || { php artisan p:upgrade && return; } # Use self-update if possible

  php artisan down

  if compare_versions "v0.7.0" "${INSTALLED_PANEL_VERSION}"; then
    curl -L https://github.com/pterodactyl/panel/releases/download/v0.7.19/panel.tar.gz | tar --strip-components=1 -xzv
    chmod -R 755 storage/* bootstrap/cache
    rm -rf bootstrap/cache/*
    php artisan view:clear
    composer install --no-dev --optimize-autoloader
    php artisan migrate --seed --force
    php artisan p:migration:clean-orphaned-keys
    update_panel; return                                                                                                   # from 0.6
  elif compare_versions "v1.0.0" "${INSTALLED_PANEL_VERSION}"; then # if 0.7.x
    log verbose "Upgrading legacy Panel!"
    curl -s -L -o panel.tar.gz https://github.com/pterodactyl/panel/releases/download/${LATEST_PANEL_RELEASE}/panel.tar.gz # from 0.7
    rm -rf $(find app public resources -depth | head -n -1 | grep -Fv "$(tar -tf panel.tar.gz)")                           # from 0.7
    tar -xzvf panel.tar.gz && rm -f panel.tar.gz                                                                           # from 0.7
  else
    curl -s -L https://github.com/pterodactyl/panel/releases/download/${LATEST_PANEL_RELEASE}/panel.tar.gz | tar -xzv      # from 1.x
  fi
  chmod -R 755 storage/* bootstrap/cache
  composer install --no-dev --optimize-autoloader
  php artisan view:clear
  php artisan config:clear
  php artisan migrate --seed --force
  chown -R $(get_file_owner ${PANEL_DIR}/storage):$(get_file_owner ${PANEL_DIR}/storage) ${PANEL_DIR}/* # chown -R www-data:www-data *
  php artisan up
  php artisan queue:restart

  log verbose "Panel update complete!"
}

write_wings_service_file() {
  log debug "Writing Wings service file!"
  local line="
    "
  local wings_service_file="
    [Unit]
    Description=Pterodactyl Wings Daemon
    After=docker.service

    [Service]
    User=root
    WorkingDirectory=/etc/pterodactyl
    LimitNOFILE=4096
    PIDFile=/var/run/wings/daemon.pid
    ExecStart=/usr/local/bin/wings
    Restart=on-failure
    StartLimitInterval=600

    [Install]
    WantedBy=multi-user.target"
    sed 's/^${line}//g' <<<$wings_service_file >/etc/systemd/system/wings.service

}

update_wings() {
  log debug "Updating Wings!"
  local ARCH=$(dpkg --print-architecture || echo "amd64")
  curl -sLo /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/download/${LATEST_WINGS_RELEASE}/wings_linux_${ARCH}

  chmod u+x /usr/local/bin/wings
  [ "${MIGRATING_WINGS}" == "false" ] && systemctl restart wings
}

migrate_to_wings() {
  log debug "Migrating to Wings from the old NodeJS Daemon!"
  mkdir -p /etc/pterodactyl
  touch /etc/pterodactyl/config.yml

  MIGRATING_WINGS=true
  update_wings

  systemctl stop wings
  rm -rf ${DAEMON_DIR}
  
  if [[ -f "/etc/systemd/system/pterosftp.service" ]]; then
    log info "Standalone Daemon SFTP server found, removing now."
    systemctl disable --now pterosftp
    rm /etc/systemd/system/pterosftp.service
  fi

  write_wings_service_file

  systemctl daemon-reload
  systemctl enable --now wings
  log debug "Migration to Wings complete!"
}

check_installed() {
  log verbose "Checking if the Panel is installed!"
  if [[ -d "${PANEL_DIR}" ]]; then         # Panel
    log debug "The Panel is installed!"
    PANEL_INSTALLED=true 
    INSTALLED_PANEL_VERSION=v$(grep \'version\' ${PANEL_DIR}/config/app.php | cut -d"'" -f4) # ex: v1.2.0
    log debug "The installed Panel version is \"${INSTALLED_PANEL_VERSION}\" at \"${PANEL_DIR}\" (Latest is \"${LATEST_PANEL_RELEASE}\")"
    log debug "$(compare_versions "${LATEST_PANEL_RELEASE}" "${INSTALLED_PANEL_VERSION}" && echo "Your Panel is out of date!" || echo "Your Panel is up to date!")"
  fi
  log verbose "Checking if Wings is installed!"
  if command -v wings &> /dev/null; then # Wings
    log debug "Wings is installed!"
    WINGS_INSTALLED=true
    INSTALLED_WINGS_VERSION=v$( (wings --version 2> /dev/null) || (wings version 2> /dev/null | awk '{print $2; exit}' | cut -c2-) ) # ex: v1.2.0

    log debug "The installed Wings version is \"${INSTALLED_WINGS_VERSION}\" (Latest is \"${LATEST_WINGS_RELEASE}\")"
    log debug "$(compare_versions "${LATEST_WINGS_RELEASE}" "${INSTALLED_WINGS_VERSION}" && echo "Wings is out of date!" || echo "Wings is up to date!")"
  fi
  log verbose "Checking if the NodeJS Daemon is installed!"
  if [ -d "${DAEMON_DIR}" ]; then        # Dameon
    log debug "The NodeJS Daemon is installed!"
    DAEMON_INSTALLED=true
    INSTALLED_DAEMON_VERSION=v$(grep \"version\" ${DAEMON_DIR}/package.json | cut -d"\"" -f4) # ex: v0.6.13
    log debug "The installed Daemon version is \"${INSTALLED_DAEMON_VERSION}\" at \"${DAEMON_DIR}\" (Latest is \"${LATEST_DAEMON_RELEASE}\")"
    log debug "$(compare_versions "${LATEST_DAEMON_RELEASE}" "${INSTALLED_DAEMON_VERSION}" && echo "Your Daemon is out of date," || echo "Your Daemon is up to date,") however Panel 1.0+ requires Wings!"
  fi
}

smart_update() {
  log info "Beginning smart update"
  check_installed

  if [[ "${PANEL_INSTALLED}" == "true" ]]; then
    compare_versions "${LATEST_PANEL_RELEASE}" "${INSTALLED_PANEL_VERSION}" && update_panel || log info "Panel is up to date! (${INSTALLED_PANEL_VERSION})"
  fi

  if [[ "${DAEMON_INSTALLED}" == "true" ]]; then
    log warn "The old NodeJS daemon is installed! Migrating to Wings now..." && migrate_to_wings
  elif [[ "${WINGS_INSTALLED}" == "true" ]]; then
    compare_versions "${LATEST_WINGS_RELEASE}" "${INSTALLED_WINGS_VERSION}" && update_wings || log info "Wings is up to date! (${INSTALLED_WINGS_VERSION})"
  fi    
}

help_menu() {
  log help "\e[1musage: VAR=val <script> [option]"
  log help
  log help "\e[1mvariables:"
  log help "PANEL_DIR=     : The Panel directory. default: /var/www/pterodactyl"
  log help "DAEMON_DIR=    : The NodeJS Daemon directory. default: /srv/daemon"
  log help
  log help "\e[1moptions:"
  log help "-h | --help    : Brings up this help menu."
  log help "-a | --auto    : Automatically updates Wings and Panel, migrating to Wings if"
  log help "                  NodeJS Daemon is detected."
  log help "-i | --info    : Lists installed versions of the Panel, NodeJS Daemon, and Wings."
  log help "-d | --debug   : Enables \e[92m[DEBUG]\e[34m messages."
  log help "-v | --verbose : Enables \e[3;95m[verbose]\e[34m messages."
}

init() {
  log info "###############################################"
  log info "#                                             #"
  log info "#         TekExplorer's Automatic             #"
  log info "#        Pterodactyl Updater Script           #"
  log info "#                                             #"
  log info "###############################################"

  PANEL_DIR=${PANEL_DIR:-/var/www/pterodactyl}
  DAEMON_DIR=${DAEMON_DIR:-/srv/daemon}

  LATEST_PANEL_RELEASE=$(get_latest_ptero_release "panel")
  LATEST_WINGS_RELEASE=$(get_latest_ptero_release "wings")
  LATEST_DAEMON_RELEASE=$(get_latest_ptero_release "daemon")
  DISCORD_LINK=$(get_latest_ptero_release "discord")

  while (($#)); do
    case "$1" in
      "" | --help | -h)
        help_menu
        exit
        ;;
      --debug | -d)
        LOG_LEVEL=debug
        ;;
      --verbose | -v)
        LOG_LEVEL=verbose
        ;;
      --check_installed | --info | -i)
        LOG_LEVEL=${LOG_LEVEL:-debug} check_installed
        exit
        ;;
      --auto-update | --auto | -a)
        enforce_root
        smart_update
        exit
        ;;
      * )
        log error "Invalid option \"$1\""
        help_menu
        exit 1
        ;;
    esac
    shift
  done
}

init "${@}"
