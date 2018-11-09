#!/bin/bash

# This script reads the given Wikipedia index to produce a file containing only its byte offsets (including the
# EOF byte offset), which can then be passed to process-wikidump.sh
#
# Params:
#
#   ${1} Path to decompressed Wikipedia index file
#        E.g., /path/to/enwiki-YYYYMMDD-pages-articles-multistream-index.txt
#
#   ${2} Path to compressed Wikipedia data file
#        E.g., /path/to/enwiki-YYYYMMDD-pages-articles-multistream.xml.bz2
#
#   ${3} (Optional) Path of file to be created, to receive the list of offsets
#        E.g., /path/to/target-offsets.txt
#        Default: ${1}.offsets
#

function fatal() {
  echo "Fatal: ${1}" >&2
  exit "${2:-1}"
}

function configure() {

  readonly INDEX_FILE="${1}"
  [[ ! -f "${INDEX_FILE}" ]] && fatal "Index file not found: ${INDEX_FILE}"

  [[ ! -f "${2}" ]] && fatal "Data file not found: ${2}"

  readonly DATA_FILE_SIZE="$(stat --printf="%s" "${2}")"
  readonly OFFSETS_FILE="${3:-"${INDEX_FILE}.offsets"}"

  local offsets_file_dir="$( dirname "${OFFSETS_FILE}" )"
  if [[ ! -d "${offsets_file_dir}" ]] ; then
    mkdir "${offsets_file_dir}" || fatal "Cannot access ${offsets_file_dir}"
  fi

  return 0
}

function main() {

  # Create the offsets file

  cat "${INDEX_FILE}" | cut -d':' -f1 | uniq > "${OFFSETS_FILE}" || fatal "Failed to write '${INDEX_FILE}'"

  # Append the ending byte offset (EOF) for the final stream...

  echo "${DATA_FILE_SIZE}" >> "${OFFSETS_FILE}"

  return 0
}

configure "$@"
main

exit 0
