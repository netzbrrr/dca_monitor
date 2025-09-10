FROM alpine:3.20

RUN apk add --no-cache \
    bash curl jq tzdata ca-certificates gawk \
 && update-ca-certificates

ENV TZ=Asia/Yangon

WORKDIR /app
COPY . /app
RUN chmod +x /app/check_dca.sh

# (entrypoint heredoc you already have stays the same)
# ...
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["crond", "-f", "-l", "8"]
