# Dockerfile
FROM alpine:3.20

RUN apk add --no-cache bash curl jq tzdata ca-certificates \
 && update-ca-certificates

# Set Myanmar time
ENV TZ=Asia/Yangon

WORKDIR /app
COPY . /app

RUN chmod +x /app/check_dca.sh

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

RUN mkdir -p /var/log

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["crond", "-f", "-l", "8"]
