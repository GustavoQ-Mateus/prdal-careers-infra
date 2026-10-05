FROM postgres:16-alpine

ARG PGVECTOR_VERSAO=0.8.1

RUN apk add --no-cache --virtual .construcao-pgvector git build-base ${DOCKER_PG_LLVM_DEPS} \
    && git clone --branch v${PGVECTOR_VERSAO} --depth 1 https://github.com/pgvector/pgvector.git /tmp/pgvector \
    && make -C /tmp/pgvector OPTFLAGS="" \
    && make -C /tmp/pgvector install \
    && rm -rf /tmp/pgvector \
    && apk del .construcao-pgvector
