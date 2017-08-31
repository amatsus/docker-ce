#
# docker run wrapper for OGS/GE
#
# Copyright (c) 2016 Akihiro Matsushima
# Released under the MIT license
# http://opensource.org/licenses/mit-license.php
#

function sigconthandler() {
    docker unpause $cid
    echo "caught sigcont, container $cid unpaused."
    wait
}
function sigusr1handler() {
    docker pause $cid
    echo "caught sigusr1, container $cid paused."
    wait
}
function sigusr2handler() {
    # Uncomment the line below if using docker v17.06.2 or earlier.
    #if [ `docker inspect --format="{{ .State.Status }}" $cid` == "paused" ]; then
    #    docker unpause $cid
    #fi

    docker stop $cid
    echo "caught sigusr2, container $cid stopped."
}
function docker() {
    # emulate fairly POSIX sh in zsh
    $(type "emulate" >/dev/null 2>&1) && emulate -L sh

    local IFS=$' \t\n'

    if [ "$1" = "run" -a -n "$SGE_ROOT" ]; then
	local DOCKER_RUN_LOCALOPTS=${DOCKER_RUN_OPTS:-'--net=bridge -u `id -u`:`id -g` --group-add=10100 -v /etc/passwd:/etc/passwd:ro -v /etc/group:/etc/group:ro -v $HOME:$HOME -v /data/$USER:/data/$USER -v /data2/$USER:/data2/$USER -w $PWD'}
	if [ -n "$JOB_ID" ]; then
	    # define the unique cidfile name
	    TEMPDIR=/var/tmp/${LOGNAME:-$USER}
	    RUNDATE=$(date +%Y%m%d%H%M%S%3N)
	    CIDFILE="${TEMPDIR}/${JOB_NAME:-SOMEJOB}.o${JOB_ID}.${SGE_TASK_ID:-SOMETASK}_${RUNDATE}.cid"
	    if [ ! -e "$TEMPDIR" ]; then
		mkdir "$TEMPDIR"
	    fi

	    echo -e "$RUNDATE\t${LOGNAME:-$USER}\t$JOB_ID\t$SGE_TASK_ID\t/usr/bin/docker run $(eval echo $DOCKER_RUN_LOCALOPTS) --cidfile=\"$CIDFILE\" ${@:2:($#-1)} &" >> ${SGE_ROOT}/default/docker_cmdline
	    /usr/bin/docker run $(eval echo $DOCKER_RUN_LOCALOPTS) --cidfile="$CIDFILE" "${@:2:($#-1)}" &
	    pid=$!
	    while [[ -d /proc/$pid && -z $cid ]]; do
		sleep 1
		if [ -s "$CIDFILE" ]; then
		    read -r cid < "$CIDFILE"
		    rm -f "$CIDFILE"
		fi
	    done

	    trap sigconthandler SIGCONT
	    trap sigusr1handler SIGUSR1
	    trap sigusr2handler SIGUSR2
	    wait
	else
	    /usr/bin/docker run $(eval echo $DOCKER_RUN_LOCALOPTS) "${@:2:($#-1)}"
	fi
    else
	/usr/bin/docker "$@"
    fi
}
if [[ ! $(readlink /proc/$$/exe) =~ "zsh" ]]; then
    export -f sigconthandler sigusr1handler sigusr2handler docker
fi

function qhost() {
    # emulate fairly POSIX sh in zsh
    $(type "emulate" >/dev/null 2>&1) && emulate -L sh

    if [ $1 = "-c" ]; then
        /opt/qhost_c/bin/qhost_c.py "${@:2:($#-1)}"
    else
        ${SGE_ROOT}/bin/linux-x64/qhost "$@"
    fi
}
