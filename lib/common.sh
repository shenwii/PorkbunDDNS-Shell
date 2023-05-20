#检测变量是否有值
#$1：变量名
lib_check_parm() {
    eval local val=\"\$"$1"\"
    if [ -z "$val" ]; then
        echo "$1 is not set"
        return 1
    fi
    return 0
}

#curl的封装
lib_curl() {
    local res=""
    for i in $(seq 1 10); do
        local res="$(curl -s "$@")"
        if [ $? = 0 ]; then
            echo "$res"
            return 0
        fi
    done
    echo "$res"
    return 1
}
