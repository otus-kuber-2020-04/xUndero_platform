FROM nginx:1.18.0-alpine
LABEL Name="xunder/testweb" Version="1.0"
#RUN apk add --no-cache shadow \
#    && usermod -u 1001 nginx \
#    && groupmod -g 1001 nginx
#RUN addgroup -g 1001 node \
#    && adduser -u 1001 -G node -s /bin/sh -D node
COPY ./app/* /app/
COPY ./web.conf /etc/nginx/conf.d/default.conf
COPY ./nginx.conf /etc/nginx/nginx.conf
EXPOSE 8000
USER 1001
