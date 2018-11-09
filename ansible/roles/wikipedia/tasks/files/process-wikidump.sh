#!/bin/bash

#
# The purpose of this script is to allow you to control the quantity and rate
# of bz2 stream extraction from the specified Wikipedia dump, and optionally
# to write the streams to HDFS
#
# Params:
#
#   ${1} Path to compressed multistream xml dump
#
#        /path/to/enwiki-YYYYMMDD-pages-articles-multistream.xml.bz2
#
#   ${2} Path to file containing the list of byte offsets to extract from the dump
#        (see prepare-offsets.sh)
#
#        /path/to/all-stream-offsets.txt
#
#   ${3} Integer denoting the max number of bz2 streams to extract from the dump.
#
#        A single stream in this context is interpreted as any two adjacent byte
#        offsets in the file given by ${2}
#
#        E.g., in the enwiki-20180620 dump, there are 185687 distinct bz2 streams,
#        with each stream (except for the last) guaranteed to contain 100
#        Wikipedia pages
#
#   ${4} Integer denoting the stream aggregation threshold, that is, the number of
#        bz2 streams from ${2} to combine into a single *.bz2 file. This allows you
#        to control the quantity and the size (roughly) of the files you're feeding
#        to mapreduce
#
#   ${5} Local directory in which to write the extracted bz2 streams
#
#   ${6} (Optional) HDFS directory to write extracted streams. If set, then files
#        will be written to this HDFS dir and then removed from local storage.
#        The directory must already exist
#

function fatal() {
  echo "Fatal: ${1}" >&2
  exit ${2:-1}
}

function checkDependencies() {

   readonly DD="$( which dd )"
   [ -z "${DD}" ] && fatal "'dd' command not found!"

   if [[ -n "${6}" ]] ; then
     HDFS="$( which hdfs )"
     if [ -z "${HDFS}" ] ; then
       # User not getting Muchos PATH info due to Ansible using non-interactive shell
       if [[ -n "${HADOOP_HOME}" && -x "${HADOOP_HOME}/bin/hdfs" ]] ; then
         source ~/.bash_profile
         HDFS="$( which hdfs )"
       fi
     fi
     [ -z "${HDFS}" ] && fatal "'hdfs' command not found!"
     readonly HDFS
   fi
}

function configure() {

   readonly WIKIDUMP_DATA="${1}"
   [ ! -f "${WIKIDUMP_DATA}" ] && fatal "Wikipedia data file does not exist: ${WIKIDUMP_DATA}"

   readonly WIKIDUMP_OFFSETS="${2}"
   [ ! -f "${WIKIDUMP_OFFSETS}" ] && fatal "Offsets file does not exist: ${WIKIDUMP_OFFSETS}"

   readonly MAX_STREAMS_TO_PROCESS="${3}"

   readonly AGGREGATION_THRESHOLD="${4}"

   readonly LOCAL_WORK_DIR="${5}"
   if [[ ! -d "${LOCAL_WORK_DIR}" ]] ; then
     mkdir "${LOCAL_WORK_DIR}" || fatal "Cannot create ${LOCAL_WORK_DIR}"
   fi

   readonly HDFS_DIR="${6}"
   [ -n "${HDFS_DIR}" ] && readonly HDFS_WRITES_ENABLED=true

   if [[ "${HDFS_WRITES_ENABLED}" == true ]] ; then
     ! ${HDFS} dfs -test -d ${HDFS_DIR} > /dev/null 2>&1 && fatal "HDFS directory doesn't exist! ${HDFS_DIR}"
   fi

   readonly NONBLOCKING_HDFS_WRITES=${NONBLOCKING_HDFS_WRITES:-false}

   readonly WIKIDUMP_NAME=$( echo "$( basename ${WIKIDUMP_DATA} )" | cut -d'-' -f1 )

   WIKIDUMP_DATE=$( echo "$( basename ${WIKIDUMP_DATA} )" | cut -d'-' -f2 )
   if [[ "${WIKIDUMP_DATE}" == "latest" ]] ; then
      WIKIDUMP_DATE="$( date +%Y%m%d )"
   fi
   readonly WIKIDUMP_DATE

   [[ ! ${WIKIDUMP_DATE} =~ ^[0-9]{8}$ ]] && fatal "Invalid date/format: ${WIKIDUMP_DATE}"

   # Read/write rate limiting for stream extraction via 'dd'
   readonly DD_BYTES_PER_READ=${DD_BYTES_PER_READ:-$((1024*1024*2))}
   readonly DD_BYTES_PER_WRITE=${DD_BYTES_PER_WRITE:-$((1024*1024*2))}
}

function flushToHdfs() {

  local hdfs_cmd="${HDFS} dfs -moveFromLocal ${1} ${HDFS_DIR}"

  if [[ "${NONBLOCKING_HDFS_WRITES}" == true ]] ; then
    nohup ${hdfs_cmd} >/dev/null 2>&1 &
  else
    ${hdfs_cmd} || return 1
  fi

  return 0
}

function extractStreams() {

  local byte_start=${1}
  local byte_count=$(( ${2} - ${1} ))
  local xmlstreams="${LOCAL_WORK_DIR}/${WIKIDUMP_NAME}-${WIKIDUMP_DATE}-$( hostname -s )-${1}-${2}.xml.bz2"

  ${DD} iflag=skip_bytes,count_bytes,noatime \
    skip=${byte_start} \
    count=${byte_count} \
    ibs=${DD_BYTES_PER_READ} \
    obs=${DD_BYTES_PER_WRITE} \
    if="${WIKIDUMP_DATA}" \
    of="${xmlstreams}" > /dev/null 2>&1 || fatal "failed to extract bz2 streams from dump!"

  if [[ "${HDFS_WRITES_ENABLED}" == true ]] ; then
    flushToHdfs "${xmlstreams}" || fatal "failed to write streams to hdfs"
  fi

  return 0
}

function main() {

   offset_start=$( head -n 1 "${WIKIDUMP_OFFSETS}" )

   total_stream_count=0
   aggregate_stream_count=0

   readonly REMAINING_OFFSETS="$( cat "${WIKIDUMP_OFFSETS}" | tail -n +2 )"
   for offset_stop in ${REMAINING_OFFSETS} ; do

      aggregate_stream_count=$(( aggregate_stream_count + 1 ))
      total_stream_count=$(( total_stream_count + 1 ))

      if (( total_stream_count == MAX_STREAMS_TO_PROCESS )) ; then
         extractStreams ${offset_start} ${offset_stop}
         echo "Max number of streams (${total_stream_count}) has been extracted. Exiting"
         exit 0
      fi

      if [[ ${aggregate_stream_count} == ${AGGREGATION_THRESHOLD} ]] ; then
        extractStreams ${offset_start} ${offset_stop}
        aggregate_stream_count=0
      else
        continue
      fi

      offset_start=${offset_stop}

   done

   # Get the leftover streams, if any
   if (( aggregate_stream_count > 0 )) ; then
     echo "Grabbing leftovers: ${offset_start} to ${offset_stop}"
     extractStreams ${offset_start} ${offset_stop}
   fi

   echo "Number of streams extracted: ${total_stream_count}"

}

checkDependencies "$@"
configure "$@"
main

exit 0

