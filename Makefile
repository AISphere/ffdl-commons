#
# Copyright 2017-2018 IBM Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

DOCKER_IMG_NAME = ffdl-service-base
IMAGE_TAG_ALPINE?=alpine3.3
IMAGE_TAG_UBUNTU?=ubuntu16.04
DLAAS_IMAGE_TAG?=$(IMAGE_TAG_UBUNTU)

include ffdl-commons.mk

install-deps: install-deps-base            ## Remove vendor directory, rebuild dependencies

clean-grpc-health-checker:
	(cd grpc-health-checker && make clean)

clean: clean-base clean-grpc-health-checker 	## clean all build artifacts
	rm -f certs/ca.*
	rm -f certs/client.*
	rm -f certs/server.*

build-grpc-health-checker:
	(cd grpc-health-checker && make build-local)

docker-build: install-deps-if-needed build-grpc-health-checker # docker-build-only       ## Install dependencies if vendor folder is missing, build go code, build docker images (includes controller).
	docker build -f Dockerfile -t $(DOCKER_IMG_NAME):$(DLAAS_IMAGE_TAG) .
	docker tag $(DOCKER_IMG_NAME):$(DLAAS_IMAGE_TAG) $(DOCKER_HOST_NAME)/$(DOCKER_NAMESPACE)/$(DOCKER_IMG_NAME):$(DLAAS_IMAGE_TAG)

docker-push: # docker-push-base
	docker push $(DOCKER_HOST_NAME)/$(DOCKER_NAMESPACE)/$(DOCKER_IMG_NAME):$(DLAAS_IMAGE_TAG)

.PHONY: build push clean
