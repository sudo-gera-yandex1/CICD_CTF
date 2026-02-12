#!/usr/bin/env bash

set -xeuo pipefail

uname -a

this_file_path="$(realpath "${0}")"
this_file_dir="$(dirname "${this_file_path}")"

(
    cd "${this_file_dir}/ssh/"

    mkdir ~/.ssh

    #  {} expands into ./path/to/file.txt
    find . -type f -exec cp {} ~/.ssh/{} \;

    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N '' -q

    cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys

    find ~/.ssh -type f -exec chmod 600 {} \;

    # add self to known hosts
    ssh 127.0.0.1 -oStrictHostKeyChecking=no true

    # add self to known hosts of repo
    ssh 127.0.0.1 -oHostKeyAlias=cicd -oStrictHostKeyChecking=no -oUserKnownHostsFile="${this_file_dir}/ssh/known_hosts" true
)

git config --global push.autoSetupRemote true

git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
git fetch --unshallow

git checkout ssh || git checkout -b ssh
cat ~/.ssh/id_ed25519.pub >> "${this_file_dir}/ssh/authorized_keys"
git add "${this_file_dir}/ssh/authorized_keys"
git commit -mm
git push
git checkout -

check_keys_interval=5

python3 -m pip install aiohttp

(set +e;(set -e

    while sleep $check_keys_interval
    do
        git fetch --all || continue

        git checkout origin/ssh -- "${this_file_dir}/ssh/authorized_keys"

        cp "${this_file_dir}/ssh/authorized_keys" ~/.ssh/

        find ~/.ssh -type f -exec chmod 600 {} \;
    done

);curl -v --max-time 1 --no-progress-meter 127.0.0.1:1)&

(set +e;(set -e

    if ! [ -f "${this_file_dir}/url.txt" ]
    then
        exit
    fi

    (set +e;(set -e

        set +e
        while sleep 1
        do
            python3 ./tcp_over_http_client.py --http-url "$( cat "${this_file_dir}/url.txt" )" --tcp-host 127.0.0.1 --tcp-port 2984
        done

    );curl -v --max-time 1 --no-progress-meter 127.0.0.1:1)&

    while sleep $check_keys_interval
    do
        if scp -oHostKeyAlias=cicd -oPort 2984 127.0.0.1:./flag.txt .
        then
            break
        else
            continue
        fi
    done

    sha256sum ./flag.txt

);curl -v --max-time 1 --no-progress-meter 127.0.0.1:1)&

(set +e;(set -e

    set +e
    while sleep 1
    do
        python3 ./tcp_over_http_server.py --http-host 127.0.0.1 --http-port 2859 --tcp-host 127.0.0.1 --tcp-port 22
    done

);curl -v --max-time 1 --no-progress-meter 127.0.0.1:1)&

(set +e;(set -e

    (
    
        for q in $(seq 1 3)
        do
            sleep 10
    
            ((
                set +e
                while sleep 1
                do
                    ssh -R 80:localhost:2859 nokey@localhost.run -- --output json | jq --unbuffered -r 'if has("address") and .address != null then "https://" + .address else empty end'
                done
            )&)
        done
            
    ) | tee "${this_file_dir}/urls.txt"

);curl -v --max-time 1 --no-progress-meter 127.0.0.1:1)&

(set +e;(set -e

    set +e
    while sleep 3500
    do
        tail -n 1 "${this_file_dir}/urls.txt" > "${this_file_dir}/url.txt"
        git add "${this_file_dir}/url.txt"
        git commit -mm || continue
        git push --force --set-upstream origin main
    done

);curl -v --max-time 1 --no-progress-meter 127.0.0.1:1)&

(set +e;(set -e

    sleep $(
        ( echo -n 'scale = 2; 3600 * 6 - 8 - ' ; cut -d' ' -f1 /proc/uptime ) | bc
    )
    touch ok

);curl -v --max-time 1 --no-progress-meter 127.0.0.1:1)&

printf 'HTTP/1.1 200 OK\r\nConnection: close\r\n\r\n' | sudo nc -N -l 1

test -f ok
