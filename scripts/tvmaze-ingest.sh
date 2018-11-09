#!/usr/bin/env bash

# This script leverages the tvmaze-ingest.yml playbook to ingest all (or any specified subset) of the
# TVMAZE database, dividing the data retrieval work evenly among the 'tvmaze' Ansible group's hosts

# The script will automatically determine how many 'plays' are required to retrieve the requested shows

readonly ANSIBLE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../ansible" && pwd )"

cd "${ANSIBLE_DIR}"

# Targeted inventory group
readonly HOST_GROUP=tvmaze

# Defaults

readonly DEFAULT_START_ID=1
readonly DEFAULT_END_ID=37199
readonly DEFAULT_SHOWS_PER_HOST=20

# Options

start_id=${DEFAULT_START_ID}
end_id=${DEFAULT_END_ID}
shows_per_host=${DEFAULT_SHOWS_PER_HOST}
ansible_verbose=""

function error() {
  echo "Error: ${1}" >&2
}

function fatal() {
  echo "Fatal: ${1}" >&2
  exit "${2:-1}"
}

function help() {
   echo
   echo " ./$( basename "$0" ) [ Options ]"
   echo "  Options:"
   echo "    -s,--start-id <int>     | Starting TVMAZE show id, inclusive. Must be > 0 and <= end id (default: ${DEFAULT_START_ID})"
   echo "    -e,--end-id <int>       | Ending TVMAZE show id, inclusive. Must be > 0 and >= start id (default: ${DEFAULT_END_ID})"
   echo "    -m,--max-per-host <int> | Max # of shows to download per host, per play. Must be > 0 (default: ${DEFAULT_SHOWS_PER_HOST})"
   echo "    -v,--verbose            | Pass '-v' flag to ansible-playbook"
   echo "    -h,--help               | Print this usage info and exit"
   echo
   echo "  Note that shows ${DEFAULT_START_ID} thru ${DEFAULT_END_ID} represents the entire TVMAZE database"
   echo

   exit "${1:-0}"
}

function assertInt() {
   [[ ! $1 =~ ^[0-9]+$ ]] && error "Bad input: '${1}' Argument to ${2} must be an integer" && help 1
}

function configure() {
   while [ "${1}" != "" ]; do
      case "${1}" in
         --start-id | -s)
            start_id="${2}"
            assertInt "${start_id}" "${1}"
            shift
            ;;
         --end-id | -e)
            end_id="${2}"
            assertInt "${end_id}" "${1}"
            shift
            ;;
         --max-per-host | -m)
            shows_per_host="${2}"
            assertInt "${shows_per_host}" "${1}"
            shift
            ;;
         --verbose | -v)
            ansible_verbose="-v"
            ;;
         --help | -h)
            help
            ;;
         *) 
         error "Invalid argument passed to $( basename "$0" ): ${1}" && help 1
      esac
      shift
   done

   (( start_id > end_id )) && error "Starting id cannot be greater than ending id" && help 1
   (( shows_per_host < 1 )) && error "Value of shows_per_host cannot be less than 1" && help 1
   (( start_id < 1 )) && error "Starting id must be >= 1" && help 1
   (( end_id < 1 )) && error "Ending id must be >= 1" && help 1
}

function setNumPlays() {
   # Determine how many plays we'll need to get all the shows downloaded
   num_hosts=$( ansible -i inventory --list-hosts ${HOST_GROUP} | head -1 | cut -d'(' -f2 | cut -d')' -f1 )
   total_downloads_per_play=$(( shows_per_host * num_hosts ))
   num_plays=$(( (end_id - start_id + 1) / total_downloads_per_play ))
   if [[ "0" != "$(( end_id % total_downloads_per_play ))" ]] ; then
      num_plays=$(( num_plays + 1 ))
   fi
}

function main() {
   # All we have to do now is execute the playbook 'num_plays' times and track the
   # starting show id for each play
   for (( i=1; i<=$num_plays; i++ )) ; do

      json_args="{ \
        \"tvmz_starting_show_id\": ${start_id}, \
        \"tvmz_max_shows_per_host\": ${shows_per_host}, \
        \"tvmz_max_show_id\": ${end_id} }"

      echo "Executing play #${i} of ${num_plays}"
      echo "Play args: ${json_args}"

      time ansible-playbook $ansible_verbose -i inventory tvmaze-ingest.yml -e "${json_args}"
      ansible_rc="$?"

      [[ "$ansible_rc" != "0" ]] && fatal "Something went terribly wrong here! Ansible RC: $ansible_rc" $ansible_rc

      start_id=$(( start_id + total_downloads_per_play ))
   done
}

configure "$@"
setNumPlays
main

exit 0
