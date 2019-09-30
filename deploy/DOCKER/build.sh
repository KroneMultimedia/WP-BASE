#!/bin/bash

# Runtime
# --------
export TERM=${TERM:-xterm}
VERBOSE=${VERBOSE:-false}

# Environment
# ------------
DB_HOST=${DB_HOST:-'db'}
DB_PORT=${DB_PORT:-'3306'}
DB_NAME=${DB_NAME:-'wordpress'}
DB_USER=${DB_USER:-'root'}
DB_PASS=${DB_PASS:-'root'}
DB_PREFIX=${DB_PREFIX:-'wp_'}
SERVER_NAME=${SERVER_NAME:-'localhost'}
ADMIN_EMAIL=${ADMIN_EMAIL:-"admin@${DB_NAME}.com"}
PERMALINKS=${PERMALINKS:-'/%year%/%monthnum%/%postname%/'}
WP_DEBUG_DISPLAY=${WP_DEBUG_DISPLAY:-'true'}
WP_DEBUG_LOG=${WB_DEBUG_LOG:-'false'}
WP_DEBUG=${WP_DEBUG:-'false'}
WP_VERSION=${WP_VERSION:-'latest'}
CUSTOM_WP_ENV=${CUSTOM_WP_ENV:-'prod'}
CREATE_DB=${CREATE_DB:-'true'}
OWNER_USER=${OWNER_USER:-'www-data'}
OWNER_GROUP=${OWNER_GROUP:-'www-data'}
[ "$SEARCH_REPLACE" ] && \
BEFORE_URL=$(echo "$SEARCH_REPLACE" | cut -d ',' -f 1) && \
AFTER_URL=$(echo "$SEARCH_REPLACE" | cut -d ',' -f 2) || \
SEARCH_REPLACE=false

. /plugin_shared.sh

export COMPOSER="composer.json"

if [ "$CI_COMMIT_REF_NAME" = "beta" ]
then
  echo "Using beta Composer"
  export COMPOSER="composer.beta.json"
fi

if [ "$CI_COMMIT_REF_NAME" = "after_build_beta" ]
then
  echo "Using beta Composer"
  export COMPOSER="composer.beta.json"
fi






main() {
  h1 "Begin WordPress Installation"
  # Wait for MySQL
  # --------------
  h2 "Configuring WordPress"


  if [ ! -f /WP_SETUP_DONE_2 ]
  then
    h3 "Composer install"

    if [ "$FORCE_COMPOSER_UPDATE" = "yes" ]
    then
      echo "FORCE UPDATE"
      composer --no-ansi  -d/app --prefer-dist  update
    fi

    composer --no-ansi  -d/app --prefer-dist  install
    composer --no-ansi  -d/app   dump-autoload
    STATUS $?

    h2 "Checking plugins"
    check_plugins



    h3 "Adjusting file permissions"
    groupadd -f docker && usermod -aG docker ${OWNER_USER}
    find /app -type d  -exec chmod 755 {} \;
    find /app -type f  -exec chmod 644 {} \;
    mkdir -p /app/wp-content/uploads
    chmod -R 775 /app/wp-content/uploads
    chown -R ${OWNER_USER}:${OWNER_GROUP} /app
    STATUS $?


    touch /WP_SETUP_DONE_2
  fi

  }



# Helpers
# --------------

RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
PURPLE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\E[1m'
NC='\033[0m'

h1() {
  local len=$(($(tput cols)-1))
  local input=$*
  local size=$(((len - ${#input})/2))

  for ((i = 0; i < len; i++)); do echo -ne "${PURPLE}${BOLD}="; done; echo ""
  for ((i = 0; i < size; i++)); do echo -n " "; done; echo -e "${NC}${BOLD}$input"
  for ((i = 0; i < len; i++)); do echo -ne "${PURPLE}${BOLD}="; done; echo -e "${NC}"
}

h2() {
  echo -e "${ORANGE}${BOLD}==>${NC}${BOLD} $*${NC}"
}

h3() {
  printf "%b " "${CYAN}${BOLD}  ->${NC} $*"
}

h3warn() {
  printf "%b " "${RED}${BOLD}  [!]|${NC} $*" && echo ""
}

STATUS() {
  local status=$1
  if [[ $1 == 'SKIP' ]]; then
    echo ""
    return
  fi
  if [[ $status != 0 ]]; then
    echo -e "${RED}✘${NC}"
    return
  fi
  echo -e "${GREEN}✓${NC}"
}

ERROR() {
  echo -e "${RED}=> ERROR (Line $1): $2.${NC}";
  exit 1;
}

WP() {
  sudo -u ${OWNER_USER} wp "$@"
}

loglevel() {
  [[ "$VERBOSE" == "false" ]] && return
  local IN
  while read -r IN; do
    echo "$IN"
  done
}

main
