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


if [ "x$XDBG_PORT" != "x" ]
then

  cat <<EOF > /usr/local/etc/php/conf.d/xdebug.ini
zend_extension=xdebug.so
xdebug.remote_enable=1
xdebug.remote_host=$NODE_IP
xdebug.remote_port=$XDBG_PORT
EOF


fi

echo probe > /app/probe.txt

# WP-CLI configuration
# ---------------------
cat > /app/wp-cli.yml <<EOF
apache_modules:
  - mod_rewrite

core config:
  dbuser: $DB_USER
  dbpass: $DB_PASS
  dbname: $DB_NAME
  dbprefix: $DB_PREFIX
  dbhost: $DB_HOST:$DB_PORT
  extra-php: |

    # Disable internal Wp-Cron function
    # @krn we have no classic cron
    # define('DISABLE_WP_CRON', true);


    function checkVarForBool(\$val) {
      if(strval(\$val) === "false") {
        return false;
      }
      if(strval(\$val) === "true") {
        return true;
      }
      return \$val;
    }

    function _define_by_env_vars(\$config_name, \$config_value_fallback) {
      define(\$config_name, getenv(\$config_name) !== false ? checkVarForBool(getenv(\$config_name)) : checkVarForBool(\$config_value_fallback));
    }
    \$host = \$_SERVER['REQUEST_SCHEME'] . '://' . \$_SERVER['HTTP_HOST'];

    # SSL by default
    if (strpos(\$_SERVER['HTTP_X_FORWARDED_PROTO'], 'https') !== false) \$_SERVER['HTTPS']='on';
    ###### define('FORCE_SSL_ADMIN', true);
    if(isset(\$_SERVER['HTTP_X_FORWARDED_PROTO'])) {
        \$host = \$_SERVER['HTTP_X_FORWARDED_PROTO'] . '://' . \$_SERVER['HTTP_HOST'];
    }

    # no revisions
    # define( 'WP_POST_REVISIONS', false );
    # define('AUTOSAVE_INTERVAL', 86400*30);

    # define('DISALLOW_FILE_EDIT', true);

    _define_by_env_vars('WP_SITEURL', \$host);
    _define_by_env_vars('WP_REDIS_DISABLED', false);
    _define_by_env_vars('WP_HOME', \$host);

    # REDIS OBJECT CACHE
    # define('WP_REDIS_HOST', 'redis');
    # define('WP_REDIS_DATABASE', 4);
    # define('WP_REDIS_MAXTTL', 800);
    # define('WP_REDIS_IGNORED_GROUPS', ['plugins', 'posts', 'post_meta', 'acf']);

    _define_by_env_vars('WP_DEBUG', ${WP_DEBUG,,});
    _define_by_env_vars('WP_DEBUG_LOG', ${WP_DEBUG_LOG,,});
    _define_by_env_vars('WP_DEBUG_DISPLAY', ${WP_DEBUG_DISPLAY,,});
    _define_by_env_vars('CUSTOM_WP_ENV', '${CUSTOM_WP_ENV,,}');

    if(WP_DEBUG) {
      define( 'SAVEQUERIES', true );
    }

    # WP_ENV
    _define_by_env_vars('WP_ENV', "local_dev");

    # WP Default Language
    define('WPLANG', 'de_DE');

    # Salts - temp generated with https://api.wordpress.org/secret-key/1.1/salt/
    define('AUTH_KEY',         'l50y)b!K,P9_}EaVEArGBtaai?;Bv&v_g%}d?[ccE8&l$/6+3}6AU7|h^dIq2Cn');
    define('SECURE_AUTH_KEY',  'UWZu 4cW0z0$IB][4&I_k+65Vl^T}(uqfpHh$Ef;0nQC.aYBw}J^]|{f2Kh6)oN*');
    define('LOGGED_IN_KEY',    'eVH+b>jwQOy14}fhc{daOc}0VI_6CrKE-c^coR75/@a+AU-~JFKey(T-XDh+0o-|');
    define('NONCE_KEY',        '2u!syL?(B~uj>nq6!sT&4cGC22m&?-vsd@B|dlyd:C!0b;QF|{;qwveQ_0FoTMs');
    define('AUTH_SALT',        ')*Fu<^~Ly[M6y,mI0mwn[yl|/;n)uQC<u,Yt?.dxTNP}2Q!}VdP^H{/|P,ad7^');
    define('SECURE_AUTH_SALT', '65FCb%WwlI_u$T|jOy:->G!txH+&$*]ok?hxQS41(Fb0Z)MS~z7#5i|(+P9Ja&e');
    define('LOGGED_IN_SALT',   'bFguo1-K{uXc)O%}mvFv ^ida(S;^e&aaC;dkB[]YTF%_Sc,]R{0|r6vIk&fR#L8');
    define('NONCE_SALT',       '*j.;8t5C=bZiqi#Yn-B@=3_Y=Pvt+aHuDz#T?qf)Zuc e<(In&V##H!?^:zZ');


    # sentry
    # _define_by_env_vars('KRN_SENTRY_DSN', 'DSN');
    # _define_by_env_vars('KRN_SENTRY_PUBLIC_DSN', 'DSN');
    # if(WP_ENV != "local_dev") {
    #  define( 'WP_SENTRY_DSN', KRN_SENTRY_DSN);
    # define( 'WP_SENTRY_PUBLIC_DSN', KRN_SENTRY_PUBLIC_DSN );
    # }
    # _define_by_env_vars('WP_SENTRY_ENV', 'undefined');
    # _define_by_env_vars('WP_SENTRY_VERSION', 'undefined');


    # multi DB
    _define_by_env_vars('KRN_DATABASES', 'undefined');

    # enable error reporting
    if(!WP_DEBUG) {
      @ini_set("display_errors", 0);
      error_reporting(E_ALL);
    }


core install:
  url: $([ "$AFTER_URL" ] && echo "$AFTER_URL" || echo localhost:8080)
  title: $DB_NAME
  admin_user: $ADMIN_USER
  admin_password: $ADMIN_PASS
  admin_email: $ADMIN_EMAIL
  skip-email: true
EOF


cat /app/wp-cli.yml

main() {
  echo  "Generating wp-config.php file..."
  rm -f /app/wp-config.php
  chmod a+rwx /app/
  wp core config --skip-check --skip-salts --allow-root
  chmod a+rw wp-config.php

  # Inject drop ins for DB
  cd /app/wp-content

  # ln -s plugins/ludicrousdb/ludicrousdb/drop-ins/db.php .
  # ln -s plugins/ludicrousdb/ludicrousdb/drop-ins/db-error.php .
  # ln -s plugins/redis-cache/includes/object-cache.php .


  if [ "x$KRN_WIPE_LANGUAGES" != "x" ]
  then
	  # having languages on wp-json only nodes is a waste of CPU
		# there is a patch available since 4 years, but not merged, remooving the folder fixes it
		# https://core.trac.wordpress.org/ticket/32052
    rm -vfr languages/*
  fi


  if [ "x$1"  = "x" ];
    then

      rm -f /var/run/apache2/apache2.pid
      source /etc/apache2/envvars
      exec apache2 -D FOREGROUND
    fi;
}

main $*
