#!/usr/bin/env sh

set -Eeuo pipefail

function inject_config() {
  local config_file="/etc/app-config.yaml"
  local config

  if [ -f "$config_file" ]; then
    # If the YAML file exists, convert it to JSON
    config="$(yq -o=json "${config_file}" | jq -cM .)"
  else
    # Read runtime config from env in the same way as the @backstage/config-loader package
    config="$(jq -n 'env |
      with_entries(select(.key | startswith("APP_CONFIG_")) | .key |= sub("APP_CONFIG_"; "")) |
      to_entries |
      reduce .[] as $item (
        {}; setpath($item.key | split("_"); $item.value | try fromjson catch $item.value)
      )')"
  fi

  >&2 echo "Runtime app config: $config"

  local main_js
  if ! main_js="$(grep -l __APP_INJECTED_RUNTIME_CONFIG__ /usr/share/nginx/html/static/*.js)"; then
    echo "Runtime config already written"
    return
  fi
  echo "Writing runtime config to ${main_js}"

  # escape ' and " twice, for both sed and json
  local config_escaped_1
  config_escaped_1="$(echo "$config" | jq -cM . | sed -e 's/[\\"'\'']/\\&/g')"
  # escape / and & for sed
  local config_escaped_2
  config_escaped_2="$(echo "$config_escaped_1" | sed -e 's/[\\/&]/\\&/g')"

  # Replace __APP_INJECTED_RUNTIME_CONFIG__ in the main chunk with the runtime config
  sed -e "s/__APP_INJECTED_RUNTIME_CONFIG__/$config_escaped_2/" -i "$main_js"
  dd if="$main_js" bs=1 skip=63750 count=400 2>/dev/null
}

# Based on this https://github.com/backstage/backstage/issues/30986#issuecomment-3386222340.
function tmp_remove_script_in_index_html() {
  sed -Ei ':a;N;$!ba;s|<script type="backstage.io/config">.*?</script>||g' /usr/share/nginx/html/index.html
}
tmp_remove_script_in_index_html

inject_config