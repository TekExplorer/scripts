#!/usr/bin/env bash

DEFAULT_BACKUP_DIR=/var/lib/ptero.sh/panel-backups
BACKUP_DIR=${1:-$DEFAULT_BACKUP_DIR}
TIME_STAMP=$(date "+%b_%d_%Y_%H_%M_%S")

echo "#########################################################"
echo "#                                                       #"
echo "#                                                       #"
echo "#     TekExplorer's Pterodactyl Panel backup script     #"
echo "#                                                       #"
echo "#                                                       #"
echo "#########################################################"
echo ""
echo "* Your backup will be saved in ${BACKUP_DIR}"
echo ""

parse_env() {
  for variable in "$@"; do
    ${variable}=$(grep ${variable}= /var/www/pterodactyl/.env | cut -d '=' -f2)
  done
}

parse_env DB_HOST DB_DATABASE DB_PASSWORD DB_USERNAME # grab variables from .env file

backup_panel() {
  mkdir -p $BACKUP_DIR/panel-$TIME_STAMP
  cp /var/www/pterodactyl/.env $BACKUP_DIR/panel-$TIME_STAMP/.env # backup .env
  echo "* .env copied!"
  mysqldump -h $DB_HOST -u $DB_USERNAME -p $DB_PASSWORD $DB_DATABASE > $BACKUP_DIR/panel-$TIME_STAMP/$DB_DATABASE.sql # Dump Panel db
  echo "* Database dumped to $DB_DATABASE.sql and copied!"
  tar -czvf $BACKUP_DIR/panel-$TIME_STAMP.tar.gz $BACKUP_DIR/panel-$TIME_STAMP # Archive backup to take less space
  echo "* Archive created at $BACKUP_DIR/panel-$TIME_STAMP.tar.gz"
 # rm -rf $BACKUP_DIR/panel-$TIME_STAMP/ # Delete folder now that archive has been made
  echo "* Deleted temporary folder!"
}

check_archive() { # checks to make sure the archive has a file
    if tar -tvf $BACKUP_DIR/panel-$TIME_STAMP.tar.gz ./$1 >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

failed_archive() { # occurs when the archive does not have an expected file
  error() {
    COLOR_RED='\033[0;31m'
    COLOR_NC='\033[0m'

    echo ""
    echo -e "* ${COLOR_RED}ERROR${COLOR_NC}: $1"
    echo ""
  }

  error "The archive does not contain the expected files! The backup has been deleted! Please try again."
  rm -rf $BACKUP_DIR/panel-$TIME_STAMP.tar.gz # Delete archive and unarchived folder
  exit 1
}

backup_panel
check_archive .env || failed_archive
check_archive ${DB_DATABASE}.sql || failed_archive

echo "* Your backup has been saved in $BACKUP_DIR/panel-$TIME_STAMP.tar.gz"
