#!/usr/bin/env bash

# Uninstall Pterodactyl Panel and/or Wings easily!
# options:
#      --help
#      --no-backup        : disables all backups
#      --no-backup-wings  : disables wings backup
#      --no-backup-panel  : disables panel backup

parse_env() {
  eval "$(
    source $envfile &>/dev/null # Source all variables temporarily
    for variable in "${@}"; do
      # -g - make variables global (out of function scope)
      # -- stop processing flags/options
      # "${variable}" - get content of the "variable"
      # "${!variable}" - get value of a variable, which name the "variable" var contains (bash reflections/indirect reference)
      # "${variable@Q}" - safely quote the content of the substitution
      printf 'declare -g -- %s\n' "${variable}=${!variable@Q}" # Safely print quoted definitions of variables
    done
  )"

  # for variable in "$@"; do
  #   echo "[DEBUG] got ${variable}=${!variable}"
  # done
}

yq() { docker run --rm -i -v "${PWD}":/workdir mikefarah/yq "$@"; }# YAML parser. if wings is installed docker probably is too.

enforce_root(){
  if [[ $EUID -ne 0 ]]; then
    log error "This script must be run as root"
    exit 1
  fi
}

yeet_service() {
  systemctl stop $1
  systemctl disable $1
  rm -f /etc/systemd/system/$1.service
  systemctl daemon-reload
  systemctl reset-failed
}

backup_panel() { curl -Ss https://raw.githubusercontent.com/TekExplorer/scripts/main/ptero/backup_panel.sh | bash -s -- ${panel_backup_dir}; }

yeet_panel_db() {
  parse_env DB_HOST DB_USER

  password_input mysql_root_password

  local sql_login="--password=${mysql_root_password} --user=root --host=${DB_HOST}"

  DB_USER_HOST=$(mysql ${sql_login} -Bse \
    "SELECT Host FROM mysql.user WHERE User ='${DB_USER}';") # gets host for db user

  mysql ${sql_login} -Bse \
    "DROP USER '${DB_USER}'@'${DB_USER_HOST}';
    DROP DATABASE ${DB_NAME};" \
    && log info "SQL deletion succeeded!" \
    || log error "Deleting SQL database and user failed! View ${manual_db_deletion_site} to see how to manually delete the database and user"

  unset mysql_root_password
}

yeet_panel() {
  # yeet panel files.
  rm -rf ${panel_dir}

  # Webserver files
  rm -f /etc/{nginx,apache2}/sites-{enabled,available}/pterodactyl.conf # Ubuntu/Debian
  rm -f /etc/{httpd,nginx}/conf.d/pterodactyl.conf # CentOS

  rm -f /var/log/nginx/pterodactyl.app-{access,error}.log

  # Restart webserver
  systemctl restart {nginx,apache2,httpd}

  # Remove pteroq service.
  yeet_service pteroq
}

yeet_wings() {
  yeet_service wings
  rm -f /usr/local/bin/wings

  wings_config_file=/etc/pterodactyl/config.yml

  local log_directory=$(yq eval '.system.log_directory' ${wings_config_file})
  local archive_directory=$(yq eval '.system.archive_directory' ${wings_config_file})

  root_directory=$(yq eval '.system.root_directory' ${wings_config_file})

  backup_directory=$(yq eval '.system.backup_directory' ${wings_config_file}) # backup files
  data_directory=$(yq eval '.system.data' ${wings_config_file}) # server files

  rm -rf $log_directory $archive_directory
  # rm -rf $backup_directory $data_directory
  # rm -rf $root_directory

  rm -rf /etc/pterodactyl
}

init_args() {
  while (($#)); do
    case "$1" in
      --help | -h) help_menu; exit ;;
      --debug | -d) LOG_LEVEL=debug ;;
      --verbose | -v) LOG_LEVEL=verbose ;;
      --no-backup) DO_PANEL_BACKUP=false; DO_WINGS_BACKUP=false ;;
      --no-backup-wings) DO_WINGS_BACKUP=false ;;
      --no-backup-panel) DO_PANEL_BACKUP=false ;;
      "" )
        backup_panel
        yeet_panel
        yeet_panel_db
        yeet_wings
        exit
        ;;
      * ) log error "Invalid option '$1'"; help_menu; exit 1 ;;
    esac
    shift
  done
}
panel_dir=${panel_dir:-/var/www/pterodactyl/}
manual_db_deletion_site=
envfile=${panel_dir}/.env
panel_backup_dir=~/pterodactyl_backup
enforce_root
init_args

# run() {
#   while [ "$done" == false ]; do
#     done=true

#     log i "What would you like to do?"
#     log i "[1] Uninstall the Panel (and make a backup)"
#     log i "[2] Uninstall the Panel (WITHOUT making a backup)"
#     log i "[3] Uninstall Wings only"
#     log i "[4] Both [1] and [3]"
#     log i "[5] Both [2] and [3]"
#     log i "[6] Nothing"

#     echo -n "* Input 1-6: "
#     read -r action

#     case $action in
#       1 )
#           backup_panel
#           yeet_panel_db
#           yeet_panel ;;
#       2 )
#           yeet_panel_db
#           yeet_panel ;;
#       3 )
#           yeet_wings ;;
#       4 )
#           backup_panel
#           yeet_panel_db
#           yeet_panel
#           yeet_wings ;;
#       5 )
#           yeet_panel_db
#           yeet_panel
#           yeet_wings ;;
#       6 )
#           exit ;;
#       * )
#           log error "Invalid option"
#           done=false ;;
#   esac
#   done
# }
