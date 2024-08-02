FROM node:21.6.2-alpine3.19

RUN apk update && apk add tar perl

ADD . /app
WORKDIR /app

CMD ["sh"]
