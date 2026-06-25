#!/opt/homebrew/bin/bash
# Directly exported from https://saeedesmaili.com/delete-unwanted-and-duplicated-items-on-1password/
declare -A itemMap

for id in $(op item list --categories Login --format=json | jq -r '.[] | select(.id != null) | .id'); do
    item=$(op item get $id --format=json)

    if [[ $item != null ]]; then
        fields=$(echo $item | jq -r '.fields')

        if [[ $fields != null ]]; then
            username=$(echo $fields | jq -r '.[] | select(.label=="username").value')
        fi

        urls=$(echo $item | jq -r '.urls')
        href=$(echo $urls | jq -r '.[0].href')
        website=$(echo $href | awk -F[/:] '{print $4}')

        if [[ -n $website && -n $username ]]; then
            key="$website-$username"

            if [[ ${itemMap[$key]} ]]; then
                echo "Duplicate found:"
                echo "Item 1: id: ${itemMap[$key]}, username: $username, website: $website"
                echo "Item 2: id: $id, username: $username, website: $website"
                op item delete $id --archive
                echo "$id deleted"
            else
                itemMap[$key]=$id
            fi
        fi
    fi
done
