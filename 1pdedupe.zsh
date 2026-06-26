#!/usr/bin/env zsh
typeset -A itemMap

zparseopts -D -F -K -- {a,-active}=flag_active \
                        {A,-account}:=flag_account \
                        {I,-ignorepassword}=flag_ignorepassword \
                        || return 1

accounts=$(op account list --format=json)
account_count=$(echo $accounts | jq '. | length')
selected_account=""

if [ $account_count -gt 1 ]; then
    if [ -n "$flag_account" ]; then
        selected_account=${flag_account[-1]}
        if ! echo $accounts | jq -e ".[] | select(.user_uuid == \"$selected_account\")" > /dev/null 2>&1; then
            echo "Account '$selected_account' not found."
            return 1
        fi
    else
        echo "Multiple accounts found:"
        echo $accounts | jq -r 'to_entries[] | "  \(.key + 1)) \(.value.email) (\(.value.url))"'
        printf "Select account [1-$account_count]: "
        read selection
        selected_account=$(echo $accounts | jq -r ".[$((selection - 1))].user_uuid")
    fi
fi

account_args=()
[[ -n $selected_account ]] && account_args=(--account $selected_account)

[ -n "$flag_ignorepassword" ] && echo "Ignoring password in duplicate detection"

[ -n "$flag_active" ] && echo "Active mode: duplicates will be deleted" || echo "Dry run mode: duplicates will not be deleted"
[ -n "$flag_active" ] && read -q "Press Enter to continue or Ctrl+C to abort..."

item_ids=($(op item list --categories Login $account_args --format=json | jq -r '.[] | select(.id != null) | .id'))
total=${#item_ids}
n=0

for id in $item_ids; do
    (( n++ ))
    item=$(op item get $id $account_args --format=json)

    if [[ $item != null ]]; then
        fields=$(echo $item | jq -r '.fields')

        if [[ $fields != null ]]; then
            title=$(echo $item | jq -r '.title')
            username=$(echo $fields | jq -r '.[] | select(.label=="username").value')
            [ -z $flag_ignorepassword ] && password=$(echo $fields | jq -r '.[] | select(.label=="password").value')
        fi

        urls=$(echo $item | jq -r '.urls // [] | .[].href')

        printf "\r\033[K[%d/%d] %s" $n $total "${title:-$id} - $username"

        if [[ -n $urls ]] && [[ -n $username ]] && [[ -n $password || -n $flag_ignorepassword ]]; then
            keybase="$urls-$username"
            [ -z $flag_ignorepassword ] && keybase="$keybase-$password"

            key=$(echo "$keybase" | base64 -w0 | sed 's/=/_/g')

            if [[ ${itemMap[$key]} ]]; then
                if [ -n "$flag_active" ]; then
                    printf " -> deleting "
                    op item delete $id $account_args --archive && printf "[OK]\n" || printf "[FAIL]\n"
                else
                    printf " -> would delete [dup of ${itemMap[$key]}]\n"
                fi
            else
                itemMap[$key]=$id
            fi
        fi
    fi
done

printf "\n"
