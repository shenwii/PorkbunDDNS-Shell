#!/bin/sh

set -e

export BASE_PWD="$(dirname "$0")"
API_URL="https://api.porkbun.com/api/json/v3"

__check_tool() {
    local tool="$1"
    which "$tool" >/dev/null 2>&1 || { echo "$tool is not installed"; return 1; }
    return 0
}

__urlencode() {
  local _str="$1"
  local _str_len=${#_str}
  local _u_i=1
  while [ "$_u_i" -le "$_str_len" ]; do
    local _str_c="$(printf "%s" "$_str" | cut -c "$_u_i")"
    case $_str_c in [a-zA-Z0-9.~_-])
      printf "%s" "$_str_c"
      ;;
    *)
      printf "%%%02X" "'$_str_c"
      ;;
    esac
    local _u_i="$(expr "${_u_i}" + 1)"
  done
}

__check_success() {
    local sts="$(echo "$1" | jq ".status")"
    if [ "$sts" = "\"SUCCESS\"" ]; then
        return 0
    else
        return 1
    fi
}

__check_api_key() {
    local key_id="$1"
    local secret="$2"
    res="$(lib_curl -X POST -H "Content-Type: application/json" \
        -d "{\"secretapikey\":\"$secret\"\
        ,\"apikey\":\"$key_id\"}" \
        "$API_URL/ping")"
    if __check_success "$res"; then
        return 0
    else
        echo "API KEY ERROR"
        exit 1
    fi
}

__get_dns_record() {
    local key_id="$1"
    local secret="$2"
    local domain="$3"
    local subdom="$4"
    local type="$5"
    lib_curl -X POST -H "Content-Type: application/json" \
        -d "{\"secretapikey\":\"$secret\"\
        ,\"apikey\":\"$key_id\"}" \
        "$API_URL/dns/retrieveByNameType/$(__urlencode "$domain")/${type}/$(__urlencode "$subdom")"
    return $?
}

__insert_dns_record() {
    local key_id="$1"
    local secret="$2"
    local domain="$3"
    local subdom="$4"
    local type="$5"
    local val="$6"
    lib_curl -X POST -H "Content-Type: application/json" \
        -d "{\"secretapikey\":\"$secret\"\
        ,\"apikey\":\"$key_id\"\
        ,\"name\":\"$subdom\"\
        ,\"type\":\"$type\"\
        ,\"content\":\"$val\"\
        ,\"ttl\":\"600\"}" \
        "$API_URL/dns/create/$(__urlencode "$domain")"
    return $?
}

__update_dns_record() {
    local key_id="$1"
    local secret="$2"
    local domain="$3"
    local subdom="$4"
    local type="$5"
    local val="$6"
    local recid="$7"
    lib_curl -X POST -H "Content-Type: application/json" \
        -d "{\"secretapikey\":\"$secret\"\
        ,\"apikey\":\"$key_id\"\
        ,\"name\":\"$subdom\"\
        ,\"type\":\"$type\"\
        ,\"content\":\"$val\"\
        ,\"ttl\":\"600\"}" \
        "$API_URL/dns/edit/$(__urlencode "$domain")/${recid}"
    return $?
}

__exec_plugins() {
    local plugin_file
    for plugin_file in "${BASE_PWD}/plugins/"*.sh; do
        if ! [ -e "$plugin_file" ]; then return 0; fi
        local plugin_base_name="$(basename "$plugin_file")"
        local plugin_name=${plugin_base_name%%.*}
        if eval [ \"\$"p_${plugin_name}_enable"\" = \"1\" ]; then
            "$plugin_file" "$@" || true
        fi
    done
}

if ! [ "$CONTAINER_RUNNING" = "1" ]; then
    . "${BASE_PWD}/PorkbunDDNS.env"
fi
. "${BASE_PWD}/lib/common.sh"

__check_tool "curl"
__check_tool "jq"

lib_check_parm "access_key_id"
lib_check_parm "access_key_secret"
lib_check_parm "domain_name"
lib_check_parm "host_record"
lib_check_parm "ip_api_url"

__check_api_key "${access_key_id}" "${access_key_secret}"

dns_type=""
if [ "$use_ipv4" = "1" ]; then
    dns_type="$dns_type A"
fi
if [ "$use_ipv6" = "1" ]; then
    dns_type="$dns_type AAAA"
fi

for iptype in $dns_type; do
    if [ "$iptype" = "A" ]; then
        ip="$(lib_curl -4 "$ip_api_url")"
        if [ $? != 0 ] || [ -z "$ip" ]; then
            echo "get ipv4 address failed"
            continue
        fi
        echo "handle ipv4..."
    else
        ip="$(lib_curl -6 "$ip_api_url")"
        if [ $? != 0 ] || [ -z "$ip" ]; then
            echo "get ipv6 address failed"
            continue
        fi
        echo "handle ipv6..."
    fi
    respon="$(__get_dns_record "${access_key_id}" "${access_key_secret}" "${domain_name}" "${host_record}" "$iptype")"
    if ! __check_success "$respon"; then
        echo "$respon"
        echo "get dns record failed."
        exit 1
    fi
    count="$(echo "$respon" | jq '.records | length')"
    if [ "$count" = 0 ]; then
        echo "insert dns record"
        __insert_dns_record "${access_key_id}" "${access_key_secret}" "${domain_name}" "${host_record}" "$iptype" "$ip"
        if ! __check_success "$respon"; then
            echo "$respon"
            echo "insert dns record failed."
            exit 1
        fi
        __exec_plugins "1" "${iptype}" "${domain_name}" "${host_record}" "" "$ip"
    else
        dns_record_id="$(echo "$respon" | jq '.records[0].id' | sed 's/"//g')"
        dns_value="$(echo "$respon" | jq '.records[0].content' | sed 's/"//g')"
        if [ "$dns_value" = "$ip" ]; then
            continue
        fi
        echo "update dns record"
        __update_dns_record "${access_key_id}" "${access_key_secret}" "${domain_name}" "${host_record}" "$iptype" "$ip" "$dns_record_id"
        if ! __check_success "$respon"; then
            echo "$respon"
            echo "update dns record failed."
            exit 1
        fi
        __exec_plugins "2" "${iptype}" "${domain_name}" "${host_record}" "$dns_value" "$ip"
    fi
done
