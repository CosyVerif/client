FROM cosyverif/docker-images:luajit
MAINTAINER Alban Linard <alban@linard.fr>

ADD . /src/cosy/client
RUN     apk add --no-cache --virtual .build-deps \
            build-base \
            make \
            perl \
            openssl-dev \
    &&  cd /src/cosy/client/ \
    &&  luarocks install rockspec/hashids-develop-0.rockspec \
    &&  luarocks install rockspec/lua-websockets-develop-0.rockspec \
    &&  luarocks make    rockspec/cosy-client-master-1.rockspec \
    &&  rm -rf /src/cosy/client \
    &&  apk del .build-deps

ENTRYPOINT ["cosy-cli"]
CMD ["--help"]
