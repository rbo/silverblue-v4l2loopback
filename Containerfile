FROM registry.fedoraproject.org/fedora:latest as builder
MAINTAINER "Robert Bohne" robert@bohne.io

ARG V4L2LOOPBACK_KERNEL_VERSION
ARG V4L2LOOPBACK_VERSION
ARG V4L2LOOPBACK_SHA256
# 0.12.5 -> e152cd6df6a8add172fb74aca3a9188264823efa5a2317fe960d45880b9406ae
# 0.12.7 -> e0782b8abe8f2235e2734f725dc1533a0729e674c4b7834921ade43b9f04939b
WORKDIR /tmp

# Install koji and use to pull kernel packages based on V4L2LOOPBACK_KERNEL_VERSION
RUN dnf install -y koji && \
    mkdir /tmp/koji && \
    cd /tmp/koji && \
    koji download-build --arch=x86_64 kernel-${V4L2LOOPBACK_KERNEL_VERSION::-7}

RUN cd /tmp/koji && \
    dnf install -y \
    gc gcc glibc-devel glibc-headers \
    ./kernel-core-${V4L2LOOPBACK_KERNEL_VERSION}.rpm ./kernel-devel-${V4L2LOOPBACK_KERNEL_VERSION}.rpm ./kernel-modules-${V4L2LOOPBACK_KERNEL_VERSION}.rpm && \
    dnf clean all -y

RUN curl -LS https://github.com/umlaeute/v4l2loopback/archive/v${V4L2LOOPBACK_VERSION}.tar.gz| \
    { t="$(mktemp)"; trap "rm -f '$t'" INT TERM EXIT; cat >| "$t"; sha256sum --quiet -c <<<"${V4L2LOOPBACK_SHA256} $t" \
    || exit 1; cat "$t"; } | tar xzf -

RUN cd /tmp/v4l2loopback-${V4L2LOOPBACK_VERSION}; \
    make -j$(nproc) && make install


FROM registry.fedoraproject.org/fedora:latest
MAINTAINER "Robert Bohne" robert@bohne.io

ARG V4L2LOOPBACK_VERSION
ARG V4L2LOOPBACK_KERNEL_VERSION
WORKDIR /tmp

COPY --from=builder /tmp/koji/ /tmp/koji/

RUN cd /tmp/koji && \
    dnf install -y ./kernel-core-${V4L2LOOPBACK_KERNEL_VERSION}.rpm ./kernel-modules-${V4L2LOOPBACK_KERNEL_VERSION}.rpm  v4l-utils && \
    rm -rf /tmp/koji

COPY --from=builder /tmp/v4l2loopback-${V4L2LOOPBACK_VERSION}/v4l2loopback.ko \
                    /usr/lib/modules/${V4L2LOOPBACK_KERNEL_VERSION}/extra/v4l2loopback.ko


CMD /usr/bin/v4l2-ctl
