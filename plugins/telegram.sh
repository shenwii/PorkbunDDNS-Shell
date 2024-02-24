#!/bin/sh

set -e

action="$1"
ip_type="$2"
domain_name="$3"
host_record="$4"
old_ip="$5"
new_ip="$6"

API_URL="https://api.telegram.org"

if ! [ "$CONTAINER_RUNNING" = "1" ]; then
    . "${BASE_PWD}/PorkbunDDNS.env"
fi
. "${BASE_PWD}/lib/common.sh"

lib_check_parm "p_telegram_botid"
lib_check_parm "p_telegram_chatid"
if [ "$action" = 1 ]; then
    lib_check_parm "p_telegram_content_create"
    eval content=\"$p_telegram_content_create\"
else
    lib_check_parm "p_telegram_content_update"
    eval content=\"$p_telegram_content_update\"
fi

respon="$(lib_curl -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "chat_id=${p_telegram_chatid}&text=${content}" "$API_URL/bot${p_telegram_botid}/sendMessage")"
if [ "$(echo "$respon" | jq '.ok')" != "true" ]; then
    echo "send message failed."
    echo "$respon"
    exit 1
fi
