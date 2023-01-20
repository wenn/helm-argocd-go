.PHONY: build
build:
	docker build -t docker-gs-ping .

.PHONY: run
run: build
	docker run --publish 8888:8888 docker-gs-ping
