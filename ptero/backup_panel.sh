#!/usr/bin/env bash

DEFAULT_BACKUP_DIR=/var/lib/ptero.sh/panel-backups
BACKUP_DIR=$(echo ${1:-$DEFAULT_BACKUP_DIR} | sed -e s./$..g)
TIME_STAMP=$(date "+%b_%d_%Y_%H_%M_%S")

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
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

read -r -p "Would you like to continue? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY]) 
        return
        ;;
    *)
        exit 1
        ;;
esac


error() {
  COLOR_RED='\033[0;31m'
  COLOR_NC='\033[0m'

  echo ""
  echo -e "* ${COLOR_RED}ERROR${COLOR_NC}: $1"
  echo ""
}

parse_env1() {
  for variable in "$@"; do
    ${variable}=$(grep ${variable}= /var/www/pterodactyl/.env | cut -d '=' -f2)
  done
}

parse_env() {
  grep $1 /var/www/pterodactyl/.env | cut -d '=' -f2
}

# grab variables from .env file
# parse_env DB_HOST DB_DATABASE DB_PASSWORD DB_USERNAME
DB_HOST=$(parse_env DB_HOST)
DB_DATABASE=$(parse_env DB_DATABASE)
DB_PASSWORD=$(parse_env DB_PASSWORD)
DB_USERNAME=$(parse_env DB_USERNAME)

backup_panel() {
  mkdir -p $BACKUP_DIR/panel-$TIME_STAMP
  cp /var/www/pterodactyl/.env $BACKUP_DIR/panel-$TIME_STAMP/.env # backup .env
  echo "* .env copied!"
  echo "* Attempting to dump database!"
  mysqldump -h $(parse_env DB_HOST) -u $(parse_env DB_USER) -p$(parse_env DB_PASSWORD) $(parse_env DB_DATABASE) > $BACKUP_DIR/panel-$TIME_STAMP/$DB_DATABASE.sql
  echo "* Database dumped to $DB_DATABASE.sql and copied!"
  
  echo "* Archiving Database and .env"
  
  cd $BACKUP_DIR/panel-$TIME_STAMP/
  tar -czvf panel-$TIME_STAMP.tar.gz .
  mv panel-$TIME_STAMP.tar.gz $BACKUP_DIR/
  
  echo "* Archive created at $BACKUP_DIR/panel-$TIME_STAMP.tar.gz"
  
  rm -rf $BACKUP_DIR/panel-$TIME_STAMP # Delete folder now that archive has been made
  echo "* Deleted temporary folder!"
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
