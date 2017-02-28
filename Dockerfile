FROM alpine
RUN apk add --no-cache ca-certificates
ADD . /
CMD ["/auth0-proxy"]
