FROM golang:1.14-buster as builder

# Set up dependencies
ENV PACKAGES curl wget jq file make git libgmp-dev gcc g++ swig

RUN apt-get update && \
    apt-get install -y $PACKAGES && \
    wget https://github.com/herumi/mcl/archive/v1.05.tar.gz && \
    tar xvf v1.05.tar.gz && cd mcl-1.05 && \
    make install && ldconfig

WORKDIR /cosmwasm
COPY . .
RUN make install

# ##################################

FROM debian:buster as hub

# Set up dependencies
ENV PACKAGES jq curl libgmpxx4ldbl libboost-serialization1.67.0

RUN apt-get update && \
    apt-get install -y $PACKAGES

COPY --from=builder /go/pkg/mod/github.com/\!cosm\!wasm/go-cosmwasm@v*/api/libgo_cosmwasm.so /usr/lib/libgo_cosmwasm.so
COPY --from=builder /go/bin/fetchcli /usr/bin/fetchcli
COPY --from=builder /go/bin/fetchd /usr/bin/fetchd
COPY --from=builder /usr/local/lib/libmcl.so /usr/lib
COPY entrypoints/entrypoint.sh /usr/bin/entrypoint.sh

VOLUME /root/.fetchd
VOLUME /root/secret-temp-config

ENTRYPOINT [ "/usr/bin/entrypoint.sh" ]
EXPOSE 1317
EXPOSE 26656
EXPOSE 26657
STOPSIGNAL SIGTERM

# ##################################

FROM hub as gcr

COPY ./entrypoints/run-node.sh /usr/bin/run-node.sh
COPY ./entrypoints/run-tx-server.sh /usr/bin/run-tx-server.sh

# ##################################

FROM hub as localnet

COPY ./entrypoints/run-localnet.sh /usr/bin/run-localnet.sh

ENTRYPOINT [ "/usr/bin/run-localnet.sh" ]

# ##################################

FROM hub as localnet-setup

RUN apt-get update && apt-get install -y python3

COPY ./entrypoints/run-localnet-setup.py /usr/bin/run-localnet-setup.py

ENV PYTHONUNBUFFERED=1

ENTRYPOINT [ "/usr/bin/run-localnet-setup.py" ]
CMD []
