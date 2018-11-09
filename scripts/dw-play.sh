#!/usr/bin/env bash

# This script is intended only to simplify your interaction with datawave.yml playbook.
# Note that any script arguments are passed thru to Ansible directly.

readonly ANSIBLE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../ansible" && pwd )"

cd "${ANSIBLE_DIR}"

ansible-playbook -i inventory datawave.yml $@