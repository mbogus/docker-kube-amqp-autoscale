FROM ubuntu:bionic

ENV PATH ${PATH}:/usr/local/go/bin
ENV GOPATH ${HOME}/go
ENV SRC_PATH ${GOPATH}/src/autoscaler
ENV BIN_DIR /data/bin
ENV GO_VER 1.14
ENV GO_SHA256 08df79b46b0adf498ea9f320a0f23d6ec59e9003660b4c9c1ce8e5e2c6f823ca

ADD bin/docker-entrypoint.sh /data/bin/

RUN \
    adduser --disabled-password --gecos '' kube && \
    DEBIAN_FRONTEND=noninteractive apt-get -y update && \
    dpkg -l > /var/tmp/dpkg_pre_deps.txt && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install wget make git gcc && \
    wget -nv --no-check-certificate https://storage.googleapis.com/golang/go${GO_VER}.linux-amd64.tar.gz && \
    shasum -a 256 go${GO_VER}.linux-amd64.tar.gz | grep ${GO_SHA256} && \
    tar -C /usr/local -xzf go${GO_VER}.linux-amd64.tar.gz && \
    rm -f go${GO_VER}.linux-amd64.tar.gz && \
    mkdir -p ${GOPATH}/{src,bin,pkg} && \
    git clone --depth 1 https://github.com/mbogus/kube-amqp-autoscale.git ${SRC_PATH} && \
    cd ${SRC_PATH} && \
    make depend && \
    make test && \
    make && \
    mv .build/autoscale ${BIN_DIR} && \
    chmod +x ${BIN_DIR}/* && \
    cd ${HOME} && \
    rm -rf ${GOPATH} && \
    rm -rf /usr/local/go && \
    chown -Rf kube:kube /data && \
    DEBIAN_FRONTEND=noninteractive apt-get purge -y --auto-remove wget make git gcc ifupdown iproute2 less manpages netbase openssh-client perl perl-modules-5.26 rename xauth && \
    DEBIAN_FRONTEND=noninteractive apt-get autoremove -y --purge && \
    DEBIAN_FRONTEND=noninteractive apt-get clean -y && \
    dpkg -l > /var/tmp/dpkg_post_deps.txt && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV GOPATH= SRC_PATH=

VOLUME /etc/default
VOLUME /data/db

USER kube
WORKDIR /data/bin

ENTRYPOINT ["/data/bin/docker-entrypoint.sh"]
CMD [""]
