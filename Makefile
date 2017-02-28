VERSION?=$(shell git describe --tags --always)
CURRENT_DOCKER_IMAGE=quintilesims/auth0-proxy:$(VERSION)
LATEST_DOCKER_IMAGE=quintilesims/auth0-proxy:latest

build:
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -o auth0-proxy .
	docker build -t $(CURRENT_DOCKER_IMAGE) .

release: build
        docker push $(CURRENT_DOCKER_IMAGE)
	docker tag  $(CURRENT_DOCKER_IMAGE) $(LATEST_DOCKER_IMAGE)
	docker push $(LATEST_DOCKER_IMAGE)

.PHONY: build release
