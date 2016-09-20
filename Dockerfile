FROM debian:testing
MAINTAINER Alban Linard <alban@linard.fr>

RUN apt-get update  --yes
RUN apt-get install --yes git curl luarocks libssl-dev
ADD . /src/cosy/client
RUN luarocks install luasec OPENSSL_LIBDIR="/usr/lib/x86_64-linux-gnu/"
RUN luarocks install https://raw.githubusercontent.com/un-def/hashids.lua/master/hashids-1.0.2-1.rockspec
RUN cd /src/cosy/client/ && \
    luarocks make rockspec/cosy-client-master-1.rockspec && \
    cd /
RUN rm -rf /src/cosy/client
ENTRYPOINT ["cosy-cli"]
CMD ["--help"]
