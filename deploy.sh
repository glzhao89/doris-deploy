## deploy.sh ##
#!/usr/bin/env bash

INSTALL_DIR="/root/install"
SRC_DIR="/root/palo"

FE_LIB_DIR="/output/fe/lib"
FE_BIN_DIR="/output/fe/bin"

BE_LIB_DIR="/output/be/lib"
BE_BIN_DIR="/output/be/bin"

FE_INSTALL_LIB="${INSTALL_DIR}${FE_LIB_DIR}"
FE_INSTALL_BIN="${INSTALL_DIR}${FE_BIN_DIR}"
FE_SRC_LIB="${SRC_DIR}${FE_LIB_DIR}"
FE_SRC_BIN="${SRC_DIR}${FE_BIN_DIR}"
FE_PID_FILE="${FE_INSTALL_BIN}/fe.pid"

BE_INSTALL_LIB="${INSTALL_DIR}${BE_LIB_DIR}"
BE_INSTALL_BIN="${INSTALL_DIR}${BE_BIN_DIR}"
BE_SRC_LIB="${SRC_DIR}${BE_LIB_DIR}"
BE_SRC_BIN="${SRC_DIR}${BE_BIN_DIR}"
BE_PID_FILE="${BE_INSTALL_BIN}/be.pid"

EDIT_LOG_PORT=9010

#echo $FE_INSTALL_LIB
#echo $FE_INSTALL_BIN
#echo $FE_SRC_LIB
#
#echo $BE_INSTALL_LIB
#echo $BE_INSTALL_BIN
#echo $BE_SRC_LIB

OPTS="$(getopt \
    -n "$0" \
    -o '' \
    -l 'fe' \
    -l 'be' \
    -l 'build' \
    -l 'helper:' \
    -- "$@")"

eval set -- "${OPTS}"

RUN_FE=0
RUN_BE=0
BUILD=0
HELPER=

if [[ "$#" == 1 ]]; then
    # default
    RUN_FE=1
    RUN_BE=1
else
    while true; do
    case "$1" in
    --fe)
        RUN_FE=1
        shift
        ;;
    --be)
        RUN_BE=1
        shift
        ;;
    --build)
        BUILD=1
        shift
        ;;
    --helper)
        HELPER=$2
        shift 2
        ;;
    --)
        shift
        break
        ;;
    *)
        echo "Internal error"
        exit 1
        ;;
    esac
    done
fi

check_pid_file() {
    local pidfile=$1
    if [[ -f "${pidfile}" ]]; then
    echo "${pidfile} exists"
    return 0
    else
    echo "no pidfile ${pidfile}"
    return 1
    fi
}

# compile
compile() {
    local daemon_name=$1
    sleep 5
    $SRC_DIR/build.sh --${daemon_name}
}

# replace library and binary
replace() {
    local daemon_name=$1
    local pidfile=""
    local install_lib=""
    local install_bin=""
    local src_lib=""
    local src_bin=""
    local pidfile_moved=0

    if [[ "${daemon_name}" == "fe" ]]; then
    pidfile=$FE_PID_FILE
    install_lib=$FE_INSTALL_LIB
    install_bin=$FE_INSTALL_BIN
    src_lib=$FE_SRC_LIB
    src_bin=$FE_SRC_BIN
    elif [[ "${daemon_name}" == "be" ]]; then
    pidfile=$BE_PID_FILE
    install_lib=$BE_INSTALL_LIB
    install_bin=$BE_INSTALL_BIN
    src_lib=$BE_SRC_LIB
    src_bin=$BE_SRC_BIN
    else
    echo "Invalid daemon name ${daemon_name}"
    fi

    check_pid_file $pidfile
    if [[ $? -eq 0 ]]; then
    #save pidfile if necessary
    cat $pidfile
    mv $pidfile $INSTALL_DIR
    pidfile_moved=1
    fi

    sleep 5
    echo "removing old ${daemon_name} lib and bin ..."
    rm -rf $install_lib
    rm -rf $install_bin

    echo "copying new ${daemon_name} lib and bin ..."
    cp -r $src_lib $install_lib
    cp -r $src_bin $install_bin

    if [[ $pidfile_moved -eq 1 ]]; then
    #restore pidfile if necessary
    echo "restoring ${pidfile}"
    mv $INSTALL_DIR/${daemon_name}.pid $install_bin
    cat $pidfile
    fi
}

# stop and start

stop_start_daemon() {
    local daemon_name=$1
    local pidfile=""
    if [[ "${daemon_name}" == "fe" ]]; then
    pidfile=$FE_PID_FILE
    elif [[ "${daemon_name}" == "be" ]]; then
    pidfile=$BE_PID_FILE
    else
    echo "Invalid daemon name ${daemon_name}"
    fi

    check_pid_file $pidfile
    if [[ $? -eq 0 ]]; then
    echo "stopping ${daemon_name} daemon..."
    stop_daemon $daemon_name
    fi

    echo "starting ${daemon_name} daemon..."
    start_daemon $daemon_name
}

stop_daemon() {
    local daemon_name=$1
    local bin=""
    if [[ "${daemon_name}" == "fe" ]]; then
    bin=$FE_INSTALL_BIN
    elif [[ "${daemon_name}" == "be" ]]; then
    bin=$BE_INSTALL_BIN
    else
    echo "Invalid daemon name ${daemon_name}"
    fi

    sleep 5
    $bin/stop_${daemon_name}.sh
}

start_daemon() {
    local daemon_name=$1
    local bin=""
    if [[ "${daemon_name}" == "fe" ]]; then
    bin=$FE_INSTALL_BIN
    elif [[ "${daemon_name}" == "be" ]]; then
    bin=$BE_INSTALL_BIN
    else
    echo "Invalid daemon name ${daemon_name}"
    fi

    sleep 5
    if [[ (x"$HELPER" != x"") && ("${daemon_name}" == "fe") ]]; then
	$bin/start_${daemon_name}.sh --helper ${HELPER}:${EDIT_LOG_PORT} --daemon
    else
        $bin/start_${daemon_name}.sh --daemon
    fi
}

if [[ "${RUN_FE}" -eq 1 ]]; then
    if [[ "${BUILD}" -eq 1 ]]; then
    echo "###### compiling FE ... ######"
    compile fe
    fi
    echo "###### install FE bin and lib... ######"
    replace fe
    echo "###### start and stop FE daemon ... ######"
    stop_start_daemon fe
fi

if [[ "${RUN_BE}" -eq 1 ]]; then
    if [[ "${BUILD}" -eq 1 ]]; then
    echo "###### compiling BE ... ######"
    compile be
    fi
    echo "###### install BE bin and lib... ######"
    replace be
    echo "###### start and stop BE daemon ... ######"
    stop_start_daemon be
fi
