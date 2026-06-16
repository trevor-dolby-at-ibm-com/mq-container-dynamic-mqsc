# mq-container-dynamic-mqsc
Dynamic application of MQSC scripts in a running container

Based on https://github.com/ibm-messaging/mq-gitops-samples/blob/main/queue-manager-deployment/components/scripts/start-mqsc.sh by Martin Evans, this repo
contains a script that will monitor multiple files and preserve checksums across restarts so the files are only applied when they are changed:

![overview-light](/pictures/overview-light.png#gh-light-mode-only)![overview-dark](/pictures/overview-dark.png#gh-dark-mode-only)


## Setup

Config maps
```
kubectl create configmap mqsc-script --from-file=update-mqsc.sh --from-file=dummy-stop.sh
kubectl create configmap example-mqsc-files --from-file=example1.mqsc=examples/example1.mqsc --from-file=example2.mqsc=examples/example2.mqsc 
```
Note that creating the config map with this script from a Windows system may lead to errors of the form
```
sh-5.1$ /mqsc-script/dummy-stop.sh
sh: /mqsc-script/dummy-stop.sh: /bin/bash^M: bad interpreter: No such file or directory
```
and this can be resolved using commands like `sed -i 's/\r//g'` to delete the extraneous CRs.

QM yaml
```
  template:
    pod:
      volumes:
        - name: mqsc-script
          configMap:
            name: mqsc-script
            defaultMode: 0777
        - name: example-mqsc-files
          configMap:
            name: example-mqsc-files
            defaultMode: 0777
      containers:
        - name: qmgr
          volumeMounts:
          - name: mqsc-script
            mountPath: /mqsc-script
            readOnly: true
          - name: example-mqsc-files
            mountPath: /dynamic-mqsc/example-mqsc-files
            readOnly: true
```

Once these are in place, the `DEFINE SERVICE` command in [start-script.mqsc](/start-script.mqsc) 
can be run manually or via another (static) MQSC script to start the monitor script.

## Expected output

Once the script is running successfully, then the first time it is run should result in logs as follows:
```

2026-06-16T01:58:47.947Z /mqsc-script/update-mqsc.sh: No hash directory specified - will use /mnt/mqm/data/mqsc-hashes/TESTQM as a default
2026-06-16T01:58:48.034Z /mqsc-script/update-mqsc.sh: starting; QM name TESTQM + MQSC top directory /dynamic-mqsc + hash directory /mnt/mqm/data/mqsc-hashes/TESTQM
2026-06-16T01:58:48.132Z /mqsc-script/update-mqsc.sh: Found new MQSC file /dynamic-mqsc/example-mqsc-files/example1.mqsc (hash info /mnt/mqm/data/mqsc-hashes/TESTQM/hash-example-mqsc-files-example1.mqsc da40f7e85b9137c8dc83353c4517dd6da012761cc3d102a029c90c573e88b739)
2026-06-16T01:58:48.138Z /mqsc-script/update-mqsc.sh: runmqsc output:
2026-06-16T01:58:48.142Z /mqsc-script/update-mqsc.sh: 5724-H72 (C) Copyright IBM Corp. 1994, 2026.
2026-06-16T01:58:48.142Z /mqsc-script/update-mqsc.sh: Starting MQSC for queue manager TESTQM.
2026-06-16T01:58:48.142Z /mqsc-script/update-mqsc.sh:
2026-06-16T01:58:48.142Z /mqsc-script/update-mqsc.sh:
2026-06-16T01:58:48.142Z /mqsc-script/update-mqsc.sh: 1 : DEFINE QL(EXAMPLE1) REPLACE
2026-06-16T01:58:48.142Z /mqsc-script/update-mqsc.sh: AMQ8006I: IBM MQ queue created.
2026-06-16T01:58:48.142Z /mqsc-script/update-mqsc.sh: One MQSC command read.
2026-06-16T01:58:48.142Z /mqsc-script/update-mqsc.sh: No commands have a syntax error.
2026-06-16T01:58:48.142Z /mqsc-script/update-mqsc.sh: All valid MQSC commands were processed.
2026-06-16T01:58:48.242Z /mqsc-script/update-mqsc.sh: Found new MQSC file /dynamic-mqsc/example-mqsc-files/example2.mqsc (hash info /mnt/mqm/data/mqsc-hashes/TESTQM/hash-example-mqsc-files-example2.mqsc f28bcf9ee17884ea81089de2f4ea7956254ed09239aae3531c484d84ce371d89)
2026-06-16T01:58:48.252Z /mqsc-script/update-mqsc.sh: runmqsc output:
2026-06-16T01:58:48.257Z /mqsc-script/update-mqsc.sh: 5724-H72 (C) Copyright IBM Corp. 1994, 2026.
2026-06-16T01:58:48.257Z /mqsc-script/update-mqsc.sh: Starting MQSC for queue manager TESTQM.
2026-06-16T01:58:48.257Z /mqsc-script/update-mqsc.sh:
2026-06-16T01:58:48.257Z /mqsc-script/update-mqsc.sh:
2026-06-16T01:58:48.257Z /mqsc-script/update-mqsc.sh: 1 : DEFINE QL(EXAMPLE2) REPLACE
2026-06-16T01:58:48.257Z /mqsc-script/update-mqsc.sh: AMQ8006I: IBM MQ queue created.
2026-06-16T01:58:48.257Z /mqsc-script/update-mqsc.sh: :
2026-06-16T01:58:48.257Z /mqsc-script/update-mqsc.sh: One MQSC command read.
2026-06-16T01:58:48.257Z /mqsc-script/update-mqsc.sh: No commands have a syntax error.
2026-06-16T01:58:48.257Z /mqsc-script/update-mqsc.sh: All valid MQSC commands were processed.
```

Subsequent runs would show
```
2026-06-16T02:00:12.433Z /mqsc-script/update-mqsc.sh: starting; QM name TESTQM + MQSC top directory /dynamic-mqsc + hash directory /mnt/mqm/data/mqsc-hashes/TESTQM
2026-06-16T02:00:12.538Z /mqsc-script/update-mqsc.sh: Unchanged MQSC file /dynamic-mqsc/example-mqsc-files/example1.mqsc (hash info /mnt/mqm/data/mqsc-hashes/TESTQM/hash-example-mqsc-files-example1.mqsc da40f7e85b9137c8dc83353c4517dd6da012761cc3d102a029c90c573e88b739 da40f7e85b9137c8dc83353c4517dd6da012761cc3d102a029c90c573e88b739)
2026-06-16T02:00:12.634Z /mqsc-script/update-mqsc.sh: Unchanged MQSC file /dynamic-mqsc/example-mqsc-files/example2.mqsc (hash info /mnt/mqm/data/mqsc-hashes/TESTQM/hash-example-mqsc-files-example2.mqsc f28bcf9ee17884ea81089de2f4ea7956254ed09239aae3531c484d84ce371d89 f28bcf9ee17884ea81089de2f4ea7956254ed09239aae3531c484d84ce371d89)
```
until the config map changes:
```
2026-06-16T02:02:39.336Z /mqsc-script/update-mqsc.sh: Found changed MQSC file /dynamic-mqsc/example-mqsc-files/example1.mqsc (hash info /mnt/mqm/data/mqsc-hashes/TESTQM/hash-example-mqsc-files-example1.mqsc 9a80bf90eedfcce35b04a26232333f03e8df677195908e505c942b9aafb6d49c da40f7e85b9137c8dc83353c4517dd6da012761cc3d102a029c90c573e88b739)
2026-06-16T02:02:39.341Z /mqsc-script/update-mqsc.sh: runmqsc output:
2026-06-16T02:02:39.345Z /mqsc-script/update-mqsc.sh: 5724-H72 (C) Copyright IBM Corp. 1994, 2026.
2026-06-16T02:02:39.345Z /mqsc-script/update-mqsc.sh: Starting MQSC for queue manager TESTQM.
2026-06-16T02:02:39.345Z /mqsc-script/update-mqsc.sh:
2026-06-16T02:02:39.345Z /mqsc-script/update-mqsc.sh:
2026-06-16T02:02:39.345Z /mqsc-script/update-mqsc.sh: 1 : DEFINE QL(EXAMPLE1) REPLACE
2026-06-16T02:02:39.345Z /mqsc-script/update-mqsc.sh: AMQ8006I: IBM MQ queue created.
2026-06-16T02:02:39.345Z /mqsc-script/update-mqsc.sh: One MQSC command read.
2026-06-16T02:02:39.345Z /mqsc-script/update-mqsc.sh: No commands have a syntax error.
2026-06-16T02:02:39.345Z /mqsc-script/update-mqsc.sh: All valid MQSC commands were processed.
```
