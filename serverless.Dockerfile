FROM node:alpine
MAINTAINER Carlos Nunez <dev@carlosnunez.me>

RUN npm install -g serverless@2.25.2 --progress=false --no-audit
RUN npm install -g serverless-domain-manager --save-dev --progress=false --no-audit
