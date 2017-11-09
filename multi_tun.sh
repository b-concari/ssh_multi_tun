#!/bin/sh -m

if [ $# -eq 0 ]; then
    echo "Tunnel ssh connections through an arbitrary number of hosts."
    echo
    echo "Usage: $0 user@host1:port[:ssh_priv_key_file] [[user@host2:port[:ssh_priv_key_file]] [user@host3:port[:ssh_priv_key_file]] ...]"
    echo
    echo "The host:port combinations specified create a path of SSH"
    echo "tunnels which end at the final host:port specified (and"
    echo "open a shell there)."
    echo
    echo "Example: $0 bryan@gateway.com bp@ssh.myprivate.com:4422 admin@192.168.1.10"
    echo
    echo "Would create an SSH tunnel to ssh.myprivate.com:4422 through"
    echo "gateway.com:22, then create another tunnel through"
    echo "ssh.myprivate.com:4422 to 192.168.1.10, then open a shell"
    echo "on that host for user \"admin\"."

    exit 0
fi

get_user() {
    USERHOST=$(echo $1 | awk -F: '{print $1}')
    echo "$USERHOST" | awk -F@ '{print $1}'
}
get_host() {
    USERHOST=$(echo $1 | awk -F: '{print $1}')
    echo "$USERHOST" | awk -F@ '{print $2}'
}
get_port() {
    PORT=$(echo $1 | awk -F: '{print $2}')
    [ -z "$PORT" ] && echo '22' || echo $PORT
}
get_priv_key() {
    echo $1 | awk -F: '{print $3}'
}

trap '{ kill $(jobs -p) 2>/dev/null; exit 0; }' EXIT

PORTSTART=40000
FIRST=1

while [ "$1" ]
do
    if [ -z "$2" ]
    then
        ssh -p $PORTSTART $USER@localhost
    else
        USER=`get_user $1`
        HOST=`get_host $1`
        PORT=`get_port $1`
        PRIVKEY=`get_priv_key $1`

        TUSER=`get_user $2`
        THOST=`get_host $2`
        TPORT=`get_port $2`

        [ "$PRIVKEY" ] && PRIVKEY="-i $PRIVKEY " || PRIVKEY=''

        if [ $FIRST -eq 1 ]
        then
            ssh -N -L $PORTSTART:$THOST:$TPORT $PRIVKEY-p $PORT $USER@$HOST &
            FIRST=0
        else
            ssh -N -L $(($PORTSTART + 1)):$THOST:$TPORT $PRIVKEY-p $PORTSTART $USER@localhost &
            let PORTSTART+=1
        fi

        while [ -z "$(nc -z 127.0.0.1 $PORTSTART 2>&1)" ]; do sleep 1; done
    fi

    shift
done
