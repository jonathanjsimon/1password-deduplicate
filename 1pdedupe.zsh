#!/usr/bin/env zsh
typeset -A itemMap

zparseopts -D -F -K -- {a,-active}=flag_active || return 1

for id in $(op item list --categories Login --format=json | jq -r '.[] | select(.id != null) | .id'); do
    item=$(op item get $id --format=json)

    if [[ $item != null ]]; then
        fields=$(echo $item | jq -r '.fields')

        if [[ $fields != null ]]; then
            title=$(echo $item | jq -r '.title')
            username=$(echo $fields | jq -r '.[] | select(.label=="username").value')
            password=$(echo $fields | jq -r '.[] | select(.label=="password").value')
        fi

        urls=$(echo $item | jq -r '.urls // [] | .[].href')

        if [[ -n $urls && -n $username && -n $password ]]; then
            echo "$id - $title - $username"

            key=$(echo "$urls-$username-$password" | base64 -w0 | sed 's/=/_/g')

            if [[ ${itemMap[$key]} ]]; then
                echo "Duplicate found:"
                echo "Item 1: id: ${itemMap[$key]}, username: $username, website: $urls"
                echo "Item 2: id: $id, username: $username, website: $urls"

                if [ -n "$flag_active" ]; then
                    echo "Deleting item 2: id: $id"
                    op item delete $id --archive
                    echo "$id deleted"
                else
                    echo "Would delete item 2: id: $id"
                fi
            else
                itemMap[$key]=$id
            fi
        fi
    fi
done
