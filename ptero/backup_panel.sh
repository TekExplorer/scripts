#!/usr/bin/env bash
set -euo pipefail

DEFAULT_BACKUP_DIR=/var/lib/ptero.sh/panel-backups
BACKUP_DIR=$(echo ${1:-$DEFAULT_BACKUP_DIR} | sed -e s./$..g)
TIME_STAMP="$(date --iso-8601=s)"
envfile=/var/www/pterodactyl/.env

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   echo "sudo may not work, so switch to root with sudo su"
   exit 1
fi

echo "#########################################################"
echo "#                                                       #"
echo "#                                                       #"
echo "#     TekExplorer's Pterodactyl Panel backup script     #"
echo "#                                                       #"
echo "#                                                       #"
echo "#########################################################"
echo ""
echo "* Your backup will be saved in: ${BACKUP_DIR}/panel-$TIME_STAMP.tar.gz"
echo ""
echo "* If you would like to change this directory, quit this script and add the directory you would like to use as an argument"
echo ""

ask_confirm() {
  read -r -p "Would you like to continue? [y/N] " response
  # ${response,,} - make whole content lowercase
  # ${response^^} - make whole content uppercase
  case "${response,,}" in
    yes|y) return;;
    *) exit 1;;
  esac
}

ask_confirm

error() {
  COLOR_RED='\033[0;31m'
  COLOR_NC='\033[0m'

  echo ""
  echo -e "* ${COLOR_RED}ERROR${COLOR_NC}: $1"
  echo ""
}

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

  for variable in "$@"; do
    echo "[DEBUG] got ${variable}=${!variable}"
  done
}

parse_env DB_HOST DB_DATABASE DB_PASSWORD DB_USERNAME


backup_panel() {
  mkdir -p $BACKUP_DIR/panel-$TIME_STAMP
  cp $envfile $BACKUP_DIR/panel-$TIME_STAMP/.env # backup .env

 # mysqldump -h $(parse_env DB_HOST) -u $(parse_env DB_USER) -p$(parse_env DB_PASSWORD) $(parse_env DB_DATABASE) > $BACKUP_DIR/panel-$TIME_STAMP/$DB_DATABASE.sql
  mysqldump -h "$DB_HOST" -u "$DB_USERNAME" –-password="${DB_PASSWORD?:required password not set}" "$DB_DATABASE" > $BACKUP_DIR/panel-$TIME_STAMP/$DB_DATABASE.sql # Dump Panel db
  
  cd $BACKUP_DIR/panel-$TIME_STAMP/
  tar -czvf panel-$TIME_STAMP.tar.gz .
  
  mv panel-$TIME_STAMP.tar.gz $BACKUP_DIR/
    
  rm -rf $BACKUP_DIR/panel-$TIME_STAMP # Delete folder now that archive has been made
}

check_archive() { # checks to make sure the archive has a file
    if tar -tvf $BACKUP_DIR/panel-$TIME_STAMP.tar.gz ./$1 >/dev/null 2>&1; then
       # echo "$1 is in archive!"
        return 0
    else
       # echo "$1 is not in archive! oh no!"
        return 1
    fi
}

failed_archive() { # occurs when the archive does not have an expected file
  error "The archive does not contain the expected files! The backup has been deleted! Please try again."
  rm -rf $BACKUP_DIR/panel-$TIME_STAMP.tar.gz # Delete archive and unarchived folder
  exit 1
}

backup_panel
check_archive .env || failed_archive
check_archive $DB_DATABASE.sql || failed_archive

echo "* Your backup has been saved in $BACKUP_DIR/panel-$TIME_STAMP.tar.gz"
