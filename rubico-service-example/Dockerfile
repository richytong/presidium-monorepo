FROM node:24-alpine
WORKDIR /home/node
COPY . .
RUN apk add curl \
  && npm i \
  && chmod +x ./run.sh \
  && rm .npmrc \
  && rm Dockerfile
USER node