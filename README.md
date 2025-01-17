# mq-container-dynamic-mqsc
Dynamic application of MQSC scripts in a running container

Based on https://github.com/ibm-messaging/mq-gitops-samples/blob/main/queue-manager-deployment/components/scripts/start-mqsc.sh by Martin Evans, this repo
contains a script that will monitor multiple files and preserver checksums across restarts so the files are only applied when they are changed.
