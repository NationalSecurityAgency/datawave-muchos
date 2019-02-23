#!/usr/bin/env bash

# This script is intended only to simplify your interaction with start-*.yml
# playbooks in order to start datawave's ingest and query services.

# Note that any script arguments are passed thru to Ansible directly.

readonly ANSIBLE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../ansible" && pwd )"

cd "${ANSIBLE_DIR}"

ansible-playbook -i inventory start-ingest.yml $@
