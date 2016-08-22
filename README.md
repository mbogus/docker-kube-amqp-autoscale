# KUBE-AMQP-AUTOSCALE Dockerfile

Dynamically scale kubernetes resources using length of an AMQP queue (number of messages available for retrieval from the queue) to determine the load on an application/Kubernetes pod.

**NOTICE**
If your application load is not queue-bound but rather CPU-sensitive, make sure to use built-in Kubernetes [Horizontal Pod Autoscaling](http://kubernetes.io/docs/user-guide/horizontal-pod-autoscaling/) instead of this project.


This repository contains **Dockerfile** of [KUBE-AMQP-AUTOSCALE](http://www.github.com/mbogus/kube-amqp-autoscale/) for [Docker](https://www.docker.com/)'s [automated build](https://hub.docker.com/r/mbogus/kube-amqp-autoscale/) published to the public [Docker Hub Registry](https://registry.hub.docker.com/).


## Base Docker Image

* [fedora](https://hub.docker.com/_/fedora/)


## Installation

1. Install [Docker](https://www.docker.com/).

2. Download [automated build](https://hub.docker.com/r/mbogus/kube-amqp-autoscale/) from public [Docker Hub Registry](https://registry.hub.docker.com/): `docker pull mbogus/kube-amqp-autoscale`

   (alternatively, you can build an image from Dockerfile: `docker build -t="mbogus/kube-amqp-autoscale" github.com/mbogus/docker-kube-amqp-autoscale`)


## Usage

### Run `autoscale`

    docker run -d -e AUTOSCALE_NAME=pod_to_scale -e AUTOSCALE_THRESHOLD=50 -e AUTOSCALE_MAX=10 -e RABBITMQ_URI=amqp://guest:guest@127.0.0.1:5672// -e RABBITMQ_QUEUE=queue_to_watch -e KUBERNETES_SERVICE_URL=http://127.0.0.1:8080 mbogus/kube-amqp-autoscale

### Run `autoscale` w/ persistent shared directories.

    docker run -d -v <db-dir>:/data/db -v <conf-dir>:/etc/default -e AUTOSCALE_NAME=pod_to_scale -e AUTOSCALE_THRESHOLD=50 -e AUTOSCALE_MAX=10 -e RABBITMQ_URI=amqp://guest:guest@127.0.0.1:5672// -e RABBITMQ_QUEUE=queue_to_watch -e KUBERNETES_SERVICE_URL=http://127.0.0.1:8080 mbogus/kube-amqp-autoscale

### Configuration environment variables:

#### Autoscale service:

* `AUTOSCALE_NS` Kubernetes namespace (default `default`)
* `AUTOSCALE_KIND` type of the Kubernetes resource to autoscale, one of `Deployment`, `ReplicationController`, `ReplicaSet` (default `Deployment`)
* `AUTOSCALE_NAME` name of the Kubernetes resource to autoscale
* `AUTOSCALE_THRESHOLD` number of messages on a queue representing maximum load on the autoscaled Kubernetes resource
* `AUTOSCALE_MIN` lower limit for the number of replicas for a Kubernetes pod that can be set by the autoscaler (default `1`)
* `AUTOSCALE_MAX` upper limit for the number of replicate for a Kubernetes pod that can be set by the autoscaler
* `AUTOSCALE_INTERVAL` time interval between Kubernetes resource scale runs in secs (default `30`)
* `AUTOSCALE_INCREASE_LIMIT` limit number of Kubernetes pods to be provisioned in a single scale iteration to max of the value, set to a number greater than 0, default `unbounded`
* `AUTOSCALE_DECREASE_LIMIT` limit number of Kubernetes pods to be terminated in a single scale iteration to max of the value, set to a number greater than 0, default `unbounded`

#### Autoscale statistics

* `AUTOSCALE_STATS_COVERAGE` required percentage of statistics to calculate average queue length (default `0.75`)
* `AUTOSCALE_STATS_INTERVAL` time interval between metrics gathering runs in seconds (default `5`)
* `AUTOSCALE_EVAL_INTERVALS` number of autoscale intervals used to calculate average queue length (default `2`)
* `AUTOSCALE_DB` sqlite3 database filename for storing  queue length statistics (default `:memory:`)

#### RabbitMQ broker and queue definitions

*Recommendations:*

* if RabbitMQ is deployed externally (not part of the Kubernetes cluster), use complete URI to locate the broker: `RABBITMQ_URI`
* if RabbitMQ is part of the cluster and DNS service has been configured, use DNS name: `RABBITMQ_HOST`
* if RabbitMQ is part of the cluster but DNS service has not been configured, try using Kubernetes service name for the broker: `KUBERNETES_RABBITMQ_SERVICE_NAME`
* whenever you can, stick to defaults

*Variables:*

* `RABBITMQ_URI` required, RabbitMQ broker URI, e.g. `amqp://guest:guest@127.0.0.1:5672//`
or:
* `RABBITMQ_HOST` RabbitMQ broker hostname (default `127.0.0.1`)
* `RABBITMQ_PORT` port number (default `5672`)
* `KUBERNETES_RABBITMQ_SERVICE_NAME` name of Kubernetes service exposing RabbitMQ broker
* `RABBITMQ_PROTO` use `amqps` for secure connections (default `amqp`)
* `RABBITMQ_USER` user name (default `guest`)
* `RABBITMQ_PASS` password (default `guest`)
* `RABBITMQ_VHOST` virtual host (default `/`)

* `RABBITMQ_QUEUE` RabbitMQ queue name to measure load on an application


#### Kubernetes cluster access

* `KUBERNETES_SERVICE_URL` Kubernetes API URL, e.g. `http://127.0.0.1:8080`
or
* `KUBERNETES_SERVICE_PROTO` (default `https`)
* `KUBERNETES_SERVICE_HOST` (default `127.0.0.1`)
* `KUBERNETES_SERVICE_PORT` (default `443`)

* `KUBERNETES_SERVICE_INSECURE` Set to `true` for connecting to Kubernetes API
  without verifying TLS certificate; unsafe, use for development only (default `false`)

**Basic authentication**

* `KUBERNETES_SERVICE_USERNAME` username for basic authentication on Kubernetes API
* `KUBERNETES_SERVICE_PASSWORD` password for basic authentication on Kubernetes API

**OAuth2 authentication (inside Kubernetes pod)**

Path to a bearer token file for OAuth authentication, on a Kubernetes pod
`/var/run/secrets/kubernetes.io/serviceaccount/token`

**TSL certificate (inside Kubernetes pod)**

Path to CA certificate file for HTTPS connections to Kubernetes API from
within a cluster `/var/run/secrets/kubernetes.io/serviceaccount/ca.crt`


## Sample Kubernetes deployment file

An all-in-one deployment that comprises of a RabbitMQ broker (`rabbitmq-broker`),
a worker node (`echo-node`) to be scaled according to number of unacknowledged
messages on `EchoQueue` queue and the autoscaler deployed as `autoscaler` adding
one node for each waiting message on the queue capped at 5.

~~~
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: autoscale-example
    component: broker
  name: rabbitmq-broker
spec:
  ports:
  - port: 5672
    name: main-port
    nodePort: 30672
  - port: 15672
    name: admin-port
    nodePort: 30080
  type: NodePort
  selector:
    app: autoscale-example
    component: broker
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: rabbitmq-broker
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: autoscale-example
        component: broker
    spec:
      containers:
      - name: rabbitmq
        image: rabbitmq:3-management
        imagePullPolicy: Always
        env:
        - name: RABBITMQ_HIPE_COMPILE
          value: "1"
        resources:
          requests:
            cpu: 200m
            memory: 200Mi
          limits:
            cpu: 500m
            memory: 500Mi
        ports:
        - containerPort: 5672
          hostPort: 5672
        - containerPort: 15672
          hostPort: 15672
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: echo-node
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: autoscale-example
        component: worker
    spec:
      containers:
      - name: echo
        image: mbogus/amqp-echo
        imagePullPolicy: Always
        env:
        - name: KUBERNETES_RABBITMQ_SERVICE_NAME
          value: RABBITMQ_BROKER
        - name: RABBITMQ_QUEUE
          value: EchoQueue
        - name: ECHO_DELAY
          value: "15"
        resources:
          requests:
            cpu: 100m
            memory: 100Mi
          limits:
            cpu: 200m
            memory: 200Mi
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: autoscaler
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: autoscale-example
        component: scaler
    spec:
      containers:
      - name: autoscale
        image: mbogus/kube-amqp-autoscale
        imagePullPolicy: Always
        env:
        - name: AUTOSCALE_NAME
          value: echo-node
        - name: AUTOSCALE_THRESHOLD
          value: "1"
        - name: AUTOSCALE_MAX
          value: "5"
        - name: RABBITMQ_QUEUE
          value: EchoQueue
        - name: KUBERNETES_RABBITMQ_SERVICE_NAME
          value: RABBITMQ_BROKER
        resources:
          requests:
            cpu: 100m
            memory: 100Mi
          limits:
            cpu: 200m
            memory: 200Mi
~~~
