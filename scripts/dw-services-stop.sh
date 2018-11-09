#!/usr/bin/env bash

# This script is intended only to simplify your interaction with stop-*.yml
# playbooks in order to shut down datawave's ingest and query services.

# Note that any script arguments are passed thru to Ansible directly.

readonly ANSIBLE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../ansible" && pwd )"

cd "${ANSIBLE_DIR}"

ansible-playbook -i inventory stop-web.yml $@
ansible-playbook -i inventory stop-ingest.yml $@