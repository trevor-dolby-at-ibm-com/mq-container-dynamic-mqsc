#!/bin/bash
#
# Copyright 2025 IBM Corp.
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# This script monitors files in a specified directory (default /dynamic-mqsc) and it
# runs any changed files at startup and dynamically during QM operation. The goal is
# to ensure the queue manager is always using the current definitions of any queues,
# channels, etc without needing a restart to pick up modified configuration.
#
# The directory is expected to be the parent directory of various config maps mounts
# and the overall tree would look something like this:
# 
# sh-5.1$ find /dynamic-mqsc 
# /dynamic-mqsc
# /dynamic-mqsc/example-mqsc-files
# /dynamic-mqsc/example-mqsc-files/..data
# /dynamic-mqsc/example-mqsc-files/example2.mqsc
# /dynamic-mqsc/example-mqsc-files/example1.mqsc
# /dynamic-mqsc/example-mqsc-files/..2025_01_20_16_27_13.1944471506
# /dynamic-mqsc/example-mqsc-files/..2025_01_20_16_27_13.1944471506/example1.mqsc
# /dynamic-mqsc/example-mqsc-files/..2025_01_20_16_27_13.1944471506/example2.mqsc
# 
# Directories beginning with ".." are excluded to avoid duplication: Kubernetes uses
# those directories for internal purposes, and this script is only interested in the
# files presented in the non-hidden directories.
#
# As well as scanning for MQSC files, the script stores the sha256 hashes of each of
# the MQSC files in a separate directory alongside the persistent QM data so changes
# can be detected. The directory defaults to /mnt/mqm/data/mqsc-hashes/${QMNAME} but
# this can be changed via a script argument.
#
# The hash files names are of the form "hash-<parent dir>-mqsc-file-name.mqsc", with
# the examples from above converting to
#
# hash-example-mqsc-files-example1.mqsc
# hash-example-mqsc-files-example2.mqsc
#
# On startup, the script scans the MQSC directory, compares hashes, and runs runmqsc
# for any mismatches or new files. The output format is compatible with the existing
# MQ console output so that log parsing works as expected if /proc/1/fd/1 is used as
# the stdout/stderr for the script.
#
# A trimmed example startup looks as follows:
#
# 2025-01-20T16:24:23.150Z /mqsc-script/update-mqsc.sh: No hash directory specified - will use /mnt/mqm/data/mqsc-hashes/test as a default
# 2025-01-20T16:24:23.162Z /mqsc-script/update-mqsc.sh: starting; QM name test + MQSC top directory /dynamic-mqsc + hash directory /mnt/mqm/data/mqsc-hashes/test
# 2025-01-20T16:24:23.345Z /mqsc-script/update-mqsc.sh: Unchanged MQSC file /dynamic-mqsc/example-mqsc-files/example2.mqsc (hash info /mnt/mqm/data/mqsc-hashes/test/hash-example-mqsc-files-example2.mqsc 530e2c52f9c3547c52cd19570b9b597dd2fcf3b07ed6f8b7553323ac5f8dea32 530e2c52f9c3547c52cd19570b9b597dd2fcf3b07ed6f8b7553323ac5f8dea32)
# 2025-01-20T16:24:23.044Z AMQ9722W: Plain text communication is enabled.
# 2025-01-20T16:24:23.077Z AMQ5026I: The listener 'SYSTEM.LISTENER.TCP.1' has started. ProcessId(152). [ArithInsert1(152), CommentInsert1(SYSTEM.LISTENER.TCP.1)]
# 2025-01-20T16:24:23.092Z AMQ5028I: The Server 'APPLY_MQSC' has started. ProcessId(154). [ArithInsert1(154), CommentInsert1(APPLY_MQSC)]
# 2025-01-20T16:24:23.265Z AMQ5806I: Queued Publish/Subscribe Daemon started for queue manager test. [CommentInsert1(test)]
# 2025-01-20T16:24:23.376Z /mqsc-script/update-mqsc.sh: Unchanged MQSC file /dynamic-mqsc/example-mqsc-files/example1.mqsc (hash info /mnt/mqm/data/mqsc-hashes/test/hash-example-mqsc-files-example1.mqsc 9a80bf90eedfcce35b04a26232333f03e8df677195908e505c942b9aafb6d49c 9a80bf90eedfcce35b04a26232333f03e8df677195908e505c942b9aafb6d49c)
#
# When changes are detected, the output includes the runmqsc output:
# 
# 2025-01-20T16:27:14.015Z /mqsc-script/update-mqsc.sh: Found changed MQSC file /dynamic-mqsc/example-mqsc-files/example1.mqsc (hash info /mnt/mqm/data/mqsc-hashes/test/hash-example-mqsc-files-example1.mqsc 549f616e292cf0d09c0766de9aabb919cd56a990c7d16cd99b4e51a0a975f03a 9a80bf90eedfcce35b04a26232333f03e8df677195908e505c942b9aafb6d49c)
# 2025-01-20T16:27:14.020Z /mqsc-script/update-mqsc.sh: runmqsc output:
# 2025-01-20T16:27:14.027Z /mqsc-script/update-mqsc.sh: 5724-H72 (C) Copyright IBM Corp. 1994, 2024.
# 2025-01-20T16:27:14.027Z /mqsc-script/update-mqsc.sh: Starting MQSC for queue manager test.
# 2025-01-20T16:27:14.027Z /mqsc-script/update-mqsc.sh:
# 2025-01-20T16:27:14.027Z /mqsc-script/update-mqsc.sh:
# 2025-01-20T16:27:14.027Z /mqsc-script/update-mqsc.sh: 1 : DEFINE QL(EXAMPLE1) REPLACE
# 2025-01-20T16:27:14.027Z /mqsc-script/update-mqsc.sh: AMQ8006I: IBM MQ queue created.
# 2025-01-20T16:27:14.027Z /mqsc-script/update-mqsc.sh: One MQSC command read.
# 2025-01-20T16:27:14.027Z /mqsc-script/update-mqsc.sh: No commands have a syntax error.
# 2025-01-20T16:27:14.027Z /mqsc-script/update-mqsc.sh: All valid MQSC commands were processed.
#


export QMNAME=$1
export MQSCTOPDIR=$2
export HASHDIR=$3

# Should match the MQ print format in the containr to make log parsing easier
DATE_COMMAND='date -u +%Y-%m-%dT%H:%M:%S.%3NZ'

if [ "$QMNAME" == "" ]; then
   echo "`${DATE_COMMAND}` $0: No QM name specified - runmqsc may not run unless a default QM is available"
fi 
if [ "$MQSCTOPDIR" == "" ]; then
   export MQSCTOPDIR=/dynamic-mqsc
   echo "`${DATE_COMMAND}` $0: No MQSC top-level directory specified - will use ${MQSCTOPDIR} as a default"
fi 
if [ "$HASHDIR" == "" ]; then
    export HASHDIR=/mnt/mqm/data/mqsc-hashes/${QMNAME}
    # The mkdir for the QM directory below doesn't seem to use the 2775 mode
    # when creating intermediate directories, so we create and chmod here.
    mkdir -p /mnt/mqm/data/mqsc-hashes
    chmod 2775 /mnt/mqm/data/mqsc-hashes
   echo "`${DATE_COMMAND}` $0: No hash directory specified - will use ${HASHDIR} as a default"
fi 
echo "`${DATE_COMMAND}` $0: starting; QM name $QMNAME + MQSC top directory ${MQSCTOPDIR} + hash directory ${HASHDIR}"
mkdir --mode=2775 -p ${HASHDIR}

firstTimeThrough=1
while true; do
    # Scan for MQSC files every time, as new ones may have been added
    #
    # Need to exclude the dot directories:
    # /dynamic-mqsc/example-mqsc-files/..2025_01_18_02_44_55.1696189690/example2.mqsc
    # /dynamic-mqsc/example-mqsc-files/..2025_01_18_02_44_55.1696189690/example1.mqsc
    # /dynamic-mqsc/example-mqsc-files/example2.mqsc
    # /dynamic-mqsc/example-mqsc-files/example1.mqsc
    #
    # so we use -not -path '*/.*' to get find to do the job for us.
    MQSCFILES=$(find ${MQSCTOPDIR}/ -not -path '*/.*' -name "*.mqsc")

    for mqscFile in $MQSCFILES; do
	# Make sure there's at least one match
	[ -e "${mqscFile}" ] || continue
	# Create  hash file for this file
	mqscFileWithoutTopDir=$(echo ${mqscFile} | sed "s|${MQSCTOPDIR}||g")
	hashFileName=$(echo hash${mqscFileWithoutTopDir} | tr '/' '-')
	hashFullPath="${HASHDIR}/${hashFileName}"
	# Compute the new hash and compare it to the old one (if any)
	currentHash=$(sha256sum ${mqscFile} | cut -d" " -f1)
	previousHash=$(cat ${hashFullPath} 2>/dev/null)
	#echo "Found MQSC file ${mqscFile} (hash info ${hashFullPath} ${currentHash} ${previousHash})"
	if [ "$previousHash" == "" ]; then
	   echo "`${DATE_COMMAND}` $0: Found new MQSC file ${mqscFile} (hash info ${hashFullPath} ${currentHash})"
	   echo "`${DATE_COMMAND}` $0: runmqsc output:"
	   runmqsc $QMNAME < ${mqscFile} 2>&1 | sed "s|^|`${DATE_COMMAND}` $0: |g"
	   if [ "${PIPESTATUS[0]}" != "0" ]; then
	       echo "`${DATE_COMMAND}` $0: ERROR: runmqsc did not complete successfully; examine previous messages for details"
	   fi
	   echo ${currentHash} > ${hashFullPath}
	   chmod 664 ${hashFullPath}
	elif [ "$previousHash" != "$currentHash" ]; then
	   echo "`${DATE_COMMAND}` $0: Found changed MQSC file ${mqscFile} (hash info ${hashFullPath} ${currentHash} ${previousHash})"
	   echo "`${DATE_COMMAND}` $0: runmqsc output:"
	   runmqsc $QMNAME < ${mqscFile} 2>&1 | sed "s|^|`${DATE_COMMAND}` $0: |g"
	   if [ "${PIPESTATUS[0]}" != "0" ]; then
	       echo "`${DATE_COMMAND}` $0: ERROR: runmqsc did not complete successfully; examine previous messages for details"
	   fi
	   echo ${currentHash} > ${hashFullPath}
	   chmod 664 ${hashFullPath}
	else
	    if [ "$firstTimeThrough" == "1" ]; then
		echo "`${DATE_COMMAND}` $0: Unchanged MQSC file ${mqscFile} (hash info ${hashFullPath} ${currentHash} ${previousHash})"
	    fi
	fi
    done
    firstTimeThrough=0
    sleep 5
done
