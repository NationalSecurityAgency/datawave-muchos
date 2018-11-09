#!/bin/bash

# This script starts wildfly with whatever args you pass
# pass in, and it polls for successful ear deployment.

# Exits with 0 if successful ear deployment detected, 1 otherwise

readonly WILDFLY_ARGS="$@"
readonly WILDFLY_CMD_START="( cd ${WILDFLY_HOME}/bin && nohup ./standalone.sh -c standalone-full.xml ${WILDFLY_ARGS} & )"

function wildflyIsRunning() {
    wildfly_pids="$(eval "pgrep -f jboss.home.dir -d ' '")"
    [ -z "${wildfly_pids}" ] && return 1 || return 0
}

function earIsDeployed() {
   if ! wildflyIsRunning ; then
      ear_status="WILDFLY_DOWN"
      return 1
   fi
   local ok="$( ${WILDFLY_HOME}/bin/jboss-cli.sh -c --command="deployment-info --name=datawave-ws-deploy-*.ear" | grep OK )"
   if [ -z "${ok}" ] ; then
      ear_status="EAR_NOT_DEPLOYED"
      return 1
   fi
   ear_status="EAR_DEPLOYED"
   return 0
}

function datawaveWebStart() {

    if wildflyIsRunning ; then
       echo "Wildfly is already running: ${wildfly_pids}"
    else
       echo "Starting Wildfly"
       eval "${WILDFLY_CMD_START}" > /dev/null 2>&1
    fi

    local pollInterval=4
    local maxAttempts=15

    echo "Polling for EAR deployment status every ${pollInterval} seconds (${maxAttempts} attempts max)"

    for (( i=1; i<=${maxAttempts}; i++ ))
    do
       if earIsDeployed ; then
          echo "DataWave Web successfully deployed (${i}/${maxAttempts})"
          return 0
       fi
       case "${ear_status}" in
          WILDFLY_DOWN)
             echo "Wildfly process not found (${i}/${maxAttempts})"
             ;;
          EAR_NOT_DEPLOYED)
             echo "Wildfly up (${wildfly_pids}). EAR deployment pending (${i}/${maxAttempts})"
             ;;
       esac
       sleep $pollInterval
    done
    return 1
}

if [ -z "${WILDFLY_HOME}" ] ; then
    echo "WILDFLY_HOME is undefined"
    exit 1
fi

datawaveWebStart || exit 1

exit 0
