FROM debian:testing
MAINTAINER Alban Linard <alban@linard.fr>

ADD . /src/cosy/client
RUN luarocks install luasec OPENSSL_LIBDIR="/lib/x86_64-linux-gnu/"
RUN cd /src/cosy/client/ && \
    luarocks make rockspec/cosy-client-master-1.rockspec && \
    cd /
RUN rm -rf /src/cosy/client
ENTRYPOINT ["cosy-client"]
CMD ["--help"]
