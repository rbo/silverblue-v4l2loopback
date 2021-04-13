FROM registry.fedoraproject.org/fedora:latest as builder
MAINTAINER "Robert Bohne" robert@bohne.io

ARG V4L2LOOPBACK_VERSION
ARG V4L2LOOPBACK_SHA256
# 0.12.5 -> e152cd6df6a8add172fb74aca3a9188264823efa5a2317fe960d45880b9406ae

WORKDIR /tmp
RUN dnf install -y \
    gc gcc glibc-devel glibc-headers \
    kernel-core kernel-devel kernel-modules && \
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

RUN dnf install -y kernel-core kernel-modules v4l-utils
COPY --from=builder /tmp/v4l2loopback-${V4L2LOOPBACK_VERSION}/v4l2loopback.ko \
                    /usr/lib/modules/${V4L2LOOPBACK_KERNEL_VERSION}/extra/v4l2loopback.ko


CMD /usr/bin/v4l2-ctl
