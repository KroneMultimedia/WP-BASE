#!/bin/bash

# mixture of WP-Registry based plugins + locally shipped via zip (aka premiums)
export PLUGINS="
        [post-duplicator]https://downloads.wordpress.org/plugin/post-duplicator.2.20.zip, \
        [date-range-filter]/LOCAL_PLUGINS/date-range-filter.zip
"
export LOCAL_PLUGINS="

"

check_plugins() {
  declare -A plugins
  local -i plugin_count=0
  local -i i=1
  local plugin_name
  local plugin_url

  # If $PLUGINS is not set => prune all existing plugins
  if [[ ! "${PLUGINS}" ]]; then
    h3 "No plugin dependencies listed"
    return
  fi

  # Correct for cases where user forgets to add trailing comma
  [[ "${PLUGINS:(-1)}" != ',' ]] && PLUGINS+=','

  # Set $plugin_count to the total number of plugins set in $PLUGINS
  while read -r -d,; do ((plugin_count++)); done <<< "$PLUGINS"

  # Iterate over each plugin set in $PLUGINS
  while read -r -d, plugin_name; do
    plugin_url=  # reset to null

    # If $plugin_name matches a URL using the new format => set $plugin_name & $plugin_url
    if [[ $plugin_name =~ ^\[.+\]https?://[www]?.+ ]]; then
      plugin_url=${plugin_name##\[*\]}
      plugin_name="$(echo "$plugin_name" | grep -oP '\[\K(.+)(?=\])')"
      wget -q -O /tmp/${plugin_name}.zip $plugin_url
    fi
    if [[ $plugin_name =~ ^\[.+\]/LOCAL_PLUGINS.+ ]]; then
      plugin_url=${plugin_name##\[*\]}
      plugin_name="$(echo "$plugin_name" | grep -oP '\[\K(.+)(?=\])')"
      if [ -d /tmp/${plugin_name} ]
      then
        rm -fr /tmp/${plugin_name}
      fi
      cp -pa $plugin_url /tmp/${plugin_name}
    fi

    plugin_url=${plugin_url:-$plugin_name}
      echo "($i/$plugin_count) '$plugin_name' not found. Installing..."

      unzip -o /tmp/${plugin_name} 2>&1
      if [ -d wp-content/plugins/${plugin_name} ]
      then
        rm -fr wp-content/plugins/${plugin_name}
      fi
      mv ${plugin_name} wp-content/plugins/

    plugins[$plugin_name]=$plugin_url
    ((i++))
  done <<< "$PLUGINS"

  local local_plugin_names



  ls -l wp-content/plugins
}
