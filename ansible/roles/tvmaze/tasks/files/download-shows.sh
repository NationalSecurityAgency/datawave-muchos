#!/bin/bash

readonly CURL="$( which curl )"

readonly MY_FIRST_SHOW=${1}
readonly MY_LAST_SHOW=${2}
readonly MAX_SHOWID=${3}
readonly MY_OUTPUT_FILE=${4}

readonly TOTAL_SHOW_COUNT=$(( MY_LAST_SHOW - MY_FIRST_SHOW + 1 ))

# RC indicating request rate limit exceeded
readonly RATE_LIMIT_EXCEEDED="429"

# RC indicating show id does not exist
readonly SHOW_ID_DNE="404"

function error() {
  echo "Error: ${1}" >&2
}

function fatal() {
  echo "Fatal: ${1}" >&2
  exit "${2:-1}"
}

function getTvShowById() {
  tvmaze_response_body=""
  tvmaze_response_status=""
  tvmaze_lookup="http://api.tvmaze.com/shows/${1}?embed=cast"

  curl_cmd="${CURL} --silent --write-out 'http_status_code:%{http_code}' -X GET ${tvmaze_lookup}"
  curl_response="$( eval "${curl_cmd}" )"
  curl_rc=$?

  [ "${curl_rc}" != "0" ] && fatal "Curl command exited with non-zero status: ${curl_rc}" 10

  tvmaze_response_body=$( echo ${curl_response} | sed -e 's/http_status_code\:.*//g' )
  tvmaze_response_status=$( echo ${curl_response} | tr -d '\n' | sed -e 's/.*http_status_code://' )
}

function report() {
  echo "Missing ID Count: ${show_id_dne_count} out of ${TOTAL_SHOW_COUNT}"
  echo "Rate Limit Exceeded Count: ${rate_limit_exceeded_count}"
}

function main() {
  show_id_dne_count=0
  rate_limit_exceeded_count=0

  for (( showid = $MY_FIRST_SHOW; showid <= $MY_LAST_SHOW; showid++ )) ; do

    if (( $showid > $MAX_SHOWID )) ; then
      echo "No more shows to download. Exceeded max id: $MAX_SHOWID"
      report
      exit 0
    fi

    getTvShowById $showid

    if [ "${tvmaze_response_status}" != "200" ] ; then
      if [ "${tvmaze_response_status}" == "${RATE_LIMIT_EXCEEDED}" ] ; then
        rate_limit_exceeded_count=$(( rate_limit_exceeded_count + 1 ))
        showid=$(( showid - 1 ));
        sleep 3
      elif [ "${tvmaze_response_status}" == "${SHOW_ID_DNE}" ] ; then
        show_id_dne_count=$(( show_id_dne_count + 1 ))
      fi
      continue
    fi

    if [ -z "${tvmaze_response_body}" ] ; then
      error "Response body is empty for show id == ${showid}"
      continue
    fi

    echo "${tvmaze_response_body}" >> "${MY_OUTPUT_FILE}"

  done
}

main
report

exit 0
