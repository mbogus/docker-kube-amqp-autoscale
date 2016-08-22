FROM fedora

ENV PATH ${PATH}:/usr/local/go/bin
ENV GOPATH ${HOME}/go
ENV SRC_PATH ${GOPATH}/src/autoscaler
ENV BIN_DIR /data/bin

ADD bin/docker-entrypoint.sh /data/bin/

RUN \
    adduser -c '' kube && \
    rpm --rebuilddb && \
    dnf -y upgrade && \
    dnf -y install tar wget make git gcc && \
    wget -nv --no-check-certificate https://storage.googleapis.com/golang/go1.7.linux-amd64.tar.gz && \
    sha256sum go1.7.linux-amd64.tar.gz | grep 702ad90f705365227e902b42d91dd1a40e48ca7f67a2f4b2fd052aaa4295cd95 && \
    tar -C /usr/local -xzf go1.7.linux-amd64.tar.gz && \
    rm -f go1.7.linux-amd64.tar.gz && \
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
    dnf remove -y tar wget make git gcc && \
    dnf clean all && \
    rpm --rebuilddb && \
    rm -rf /var/lib/rpm/__db* /tmp/* /var/tmp/* /var/cache/dnf/*

ENV GOPATH= SRC_PATH=

VOLUME /etc/default
VOLUME /data/db

USER kube
WORKDIR /data/bin

ENTRYPOINT ["/data/bin/docker-entrypoint.sh"]
CMD [""]
