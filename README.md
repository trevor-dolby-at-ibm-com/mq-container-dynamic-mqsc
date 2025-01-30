# mq-container-dynamic-mqsc
Dynamic application of MQSC scripts in a running container

Based on https://github.com/ibm-messaging/mq-gitops-samples/blob/main/queue-manager-deployment/components/scripts/start-mqsc.sh by Martin Evans, this repo
contains a script that will monitor multiple files and preserver checksums across restarts so the files are only applied when they are changed.

## Setup

Config maps
```bash
kubectl create configmap mqsc-script --from-file=update-mqsc.sh --from-file=dummy-stop.sh
kubectl create configmap example-mqsc-files --from-file=example1.mqsc=examples/example1.mqsc --from-file=example2.mqsc=examples/example2.mqsc 
```

QM yaml
```yaml
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

## Supply start-script as a configmap

We need to execute start-script.mqsc when a queue manager is deployed. To achieve this, we can supply the MQSC data in a configmap. Once the QM is deployed, it will process start-script.mqsc thus creating the service that will dynamically update the QueueManager. These must be created in the same namespace (project) with the queue manager. See [Example: Supplying MQSC and INI files](https://www.ibm.com/docs/en/ibm-mq/9.4?topic=manager-example-supplying-mqsc-ini-files) for more details

```bash
kubectl create configmap test-startup-script --from-file=start-script.mqsc
```

Supply MQSC to QueueManager yaml

```yaml
  queueManager:
    mqsc:
      - configMap:
          items:
            - start-script.mqsc
          name: test-startup-service
```
