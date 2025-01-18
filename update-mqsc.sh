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

export QMNAME=$1
export MQSCTOPDIR=$2
export HASHDIR=$3

if [ "$QMNAME" == "" ]; then
   echo "No QM name specified - runmqsc may not run unless a default QM is available"
fi 
if [ "$MQSCTOPDIR" == "" ]; then
   export MQSCTOPDIR=/dynamic-mqsc
   echo "No MQSC top-level directory specified - will use ${MQSCTOPDIR} as a default"
fi 
if [ "$HASHDIR" == "" ]; then
   export HASHDIR=/mnt/mqm/data/mqsc-hashes/${QMNAME}
   echo "No hash directory specified - will use ${HASHDIR} as a default"
fi 
mkdir -p ${HASHDIR}

while true; do
    # Scan for MQSC files every time, as new ones may have been added
    MQSCFILES=$(find ${MQSCTOPDIR}/ -type f -name "*.mqsc")

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
	#echo "Found MQSC file ${mqscFile} ${hashFullPath} ${currentHash} ${previousHash}"
	if [ "$previousHash" == "" ]; then
	   echo "Found new MQSC file ${mqscFile} ${hashFullPath} ${currentHash}"
	   runmqsc $QMNAME < ${mqscFile}
	   echo ${currentHash} > ${hashFullPath}
	elif [ "$previousHash" != "$currentHash" ]; then
	   echo "Found changed MQSC file ${mqscFile} ${hashFullPath} ${currentHash} ${previousHash}"
	   runmqsc $QMNAME < ${mqscFile}
	   echo ${currentHash} > ${hashFullPath}
	fi
    done
    sleep 5
done
