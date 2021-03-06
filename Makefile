CONTAINER_NAME ?= jenkins-server-container

install:
	./scripts/install.sh

clean:
	docker rm -v $$(docker ps -a -q | grep -v "$$(docker ps -q | xargs | sed 's/ /\\\|/g') ") 2>/dev/null || echo Nothing to do
	docker rmi $$(docker images --no-trunc | grep none | awk '{print $$3 }') 2>/dev/null || echo Nothing to do

build:
	./scripts/build.sh

tag:
	docker tag jenkins_server:latest jenkins_server:$(shell date +%Y%m%d%H%M%S)

start:
	docker run -d \
		--name $(CONTAINER_NAME) \
		-p 8080:8080 \
		-v /var/jenkins_home:/var/jenkins_home \
		-v /var/jenkins_bkp:/var/jenkins_bkp \
		-v /var/run/docker.sock:/var/run/docker.sock \
		--restart always \
		jenkins_server

stop:
	@echo 'Stopping $(CONTAINER_NAME)'
	docker stop $(CONTAINER_NAME)

rebuild: build tag stop clean start

dev:
	mkdir -p .docker-dev/backup
	mkdir -p .docker-dev/jenkins_home
	sudo chown 1000:1000 .docker-dev/jenkins_home .docker-dev/backup
	docker run -ti --rm \
		--name jenkins-server-dev \
		-p 8080:8080 \
		-v `pwd`/.docker-dev/backup:/var/jenkins_bkp \
		--volumes-from jenkins-server-dind \
		jenkins_server

dev.dind:
	docker run -d -ti \
		--privileged \
		--name jenkins-server-dind \
		-v `pwd`/.docker-dev/jenkins_home:/var/jenkins_home \
		-v `pwd`/.docker-dev/run:/var/run \
		fgrehm/alpine-dind
	@sleep 4
	sudo chown 0:999 .docker-dev/run/docker.sock
	sudo chmod +g .docker-dev/run/docker.sock

dev.clean:
	docker stop jenkins-server-dind || true
	docker rm -fv jenkins-server-dind || true
	docker stop jenkins-server-dev || true
	docker rm -fv jenkins-server-dev || true
	sudo rm -rf .docker-dev/*

# TODO: Get this to run inside the DinD instance we have around
test: test.build
	@docker history jenkins-server-tests 1>/dev/null
	docker run -ti --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v /tmp:/tmp \
		-v `pwd`:/workspace \
		jenkins-server-tests \
		basht /workspace/tests/*.bash

# TODO: Get this to build inside the DinD instance we have around
test.build:
	docker build -t jenkins-server-tests -f Dockerfile.test .

.PHONY: install clean build start stop rebuild dev dev.dind dev.clean test test.build
