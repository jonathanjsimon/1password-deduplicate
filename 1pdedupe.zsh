#!/usr/bin/env zsh
typeset -A itemMap

zparseopts -D -F -K -- {a,-active}=flag_active || return 1

item_ids=($(op item list --categories Login --format=json | jq -r '.[] | select(.id != null) | .id'))
total=${#item_ids}
n=0

for id in $item_ids; do
    (( n++ ))
    item=$(op item get $id --format=json)

    if [[ $item != null ]]; then
        fields=$(echo $item | jq -r '.fields')

        if [[ $fields != null ]]; then
            title=$(echo $item | jq -r '.title')
            username=$(echo $fields | jq -r '.[] | select(.label=="username").value')
            password=$(echo $fields | jq -r '.[] | select(.label=="password").value')
        fi

        urls=$(echo $item | jq -r '.urls // [] | .[].href')

        printf "\r\033[K[%d/%d] %s" $n $total "${title:-$id} - $username"

        if [[ -n $urls && -n $username && -n $password ]]; then
            key=$(echo "$urls-$username-$password" | base64 -w0 | sed 's/=/_/g')

            if [[ ${itemMap[$key]} ]]; then
                if [ -n "$flag_active" ]; then
                    printf "  →  deleting "
                    op item delete $id --archive && printf "[OK]\n" || { printf "[FAIL]\n" }
                else
                    printf "  →  would delete [dup of ${itemMap[$key]}]\n"
                fi
            else
                itemMap[$key]=$id
            fi
        fi
    fi
done

printf "\n"
