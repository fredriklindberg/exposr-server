ARG NODE_VERSION
FROM node:${NODE_VERSION}-bullseye-slim AS builder
RUN apt update && apt install -y \
    build-essential \
    cmake \
    libjemalloc2 \
    python3 \
    curl \
    git
RUN git config --global --add safe.directory /workdir
RUN cp /root/.gitconfig /etc/gitconfig
RUN touch /.yarnrc && chmod 666 /.yarnrc
RUN mkdir /.npm && chmod 777 /.npm
RUN npm -g install node-gyp
WORKDIR /workdir
CMD ["/bin/sh"]

FROM builder AS dist
ENV NODE_ENV=production
ARG DIST_SRC
COPY ${DIST_SRC} /exposrd.tgz
RUN tar xvf /exposrd.tgz -C /
WORKDIR /package
RUN yarn install --production --no-default-rc --frozen-lockfile

FROM debian:bookworm-slim as runner
ENV NODE_ENV=production
COPY --from=dist /usr/local/bin/node /bin/node
COPY --from=dist /usr/lib/*/libjemalloc.so.2 /usr/lib/libjemalloc.so.2
COPY --from=dist /package/exposrd.mjs /app/exposrd.mjs
COPY --from=dist /package/node_modules /app/node_modules
RUN mkdir -p /entrypoint-initdb.d
COPY docker/entrypoint.sh /entrypoint.sh
ENV LD_PRELOAD=/usr/lib/libjemalloc.so.2
WORKDIR /app
EXPOSE 8080
EXPOSE 8081

ENTRYPOINT ["/entrypoint.sh"]