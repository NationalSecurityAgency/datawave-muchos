#!/usr/bin/env bash

# This script is intended only to simplify your interaction with datawave.yml playbook
# for the purpose of forcing a rebuild and redeploy of datawave on your cluster.

# Note that any script arguments are passed thru to Ansible directly.

readonly SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

"${SCRIPT_DIR}"/dw-play.sh -e '{ "dw_force_redeploy": true }' $@
