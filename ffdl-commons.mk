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

#
# Common variables and targets for FfDL Makefiles
#

SHELL = /bin/sh

# The ip or hostname of the Docker host.
# Note the awkward name is to avoid clashing with the DOCKER_HOST_NAME variable.
DOCKERHOST_HOST ?= localhost

# ----- Docker-specific variables -----
WHOAMI ?= $(shell whoami)
IMAGE_TAG ?= user-$(WHOAMI)

# Image tage for docker build and push
DLAAS_IMAGE_TAG ?= user-$(WHOAMI)

DOCKER_BX_NS_HOST ?= registry.ng.bluemix.net
DOCKER_HOST_NAME ?= ${DOCKER_BX_NS_HOST}
DOCKER_NAMESPACE ?= dlaas_dev
DOCKER_REPO_USER ?= user-test
DOCKER_REPO_PASS ?= test
DOCKER_PULL_POLICY ?= Always

# DOCKER_IMG_NAME must be set by enclosing Makefile.
DOCKER_IMG_NAME ?= "VALUE_MUST_BE_SET_BY_ENCLOSING_MAKEFILE!"

# ----- repo names and lists -----

REPO_COMMONS = ffdl-commons
REPO_RESTAPIS ?= ffdl-rest-apis
REPO_APITESTS ?= "ffdl-e2e-test"
REPO_LCM ?= ffdl-lcm
REPO_TRAINER ?= ffdl-trainer
REPO_TDS ?= ffdl-model-metrics

REPOS_CORE_FFDL_SERVICE ?= ${REPO_LCM} ${REPO_TDS} ${REPO_TRAINER}
REPOS_CORE_FFDL ?= ${REPOS_CORE_FFDL_SERVICE}
REPOS_ALL_SERVICE ?= ${REPOS_CORE_FFDL_SERVICE} ${REPO_RESTAPIS}
REPOS_ALL_CERT_REPOS ?= ${REPOS_CORE_FFDL} ${REPO_RESTAPIS}
REPOS_ALL ?= ${REPOS_CORE_FFDL} ${REPO_COMMONS}

# Get all repos from org.
REPOS_ALL_IN_ORG ?= $(shell curl -s https://api.github.com/orgs/AISphere/repos?per_page=10 | jq .[].ssh_url | xargs -n 1 echo)

# Dir of where ever this is used
THIS_DIR := $(shell pwd)

COMMONS_DIR := $(strip $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST)))))
AISPHERE_DIR ?= $(shell dirname "$(COMMONS_DIR)")
MAINBIN_DIR := ${AISPHERE_DIR}/${REPO_TRAINER}/bin

KUBE_CURRENT_CONTEXT ?= $(shell kubectl config current-context)

# Support two different Kuberentes clusters:
# - one to deploy the DLaaS microservices
# - one to deploy the learners and parameter servers.
DLAAS_SERVICES_KUBE_CONTEXT ?= $(KUBE_CURRENT_CONTEXT)

DLAAS_SERVICES_KUBE_NAMESPACE ?= $(shell env DLAAS_KUBE_CONTEXT=$(DLAAS_SERVICES_KUBE_CONTEXT) ${MAINBIN_DIR}/kubecontext.sh namespace)

KUBE_SERVICES_CONTEXT_ARGS = --context $(DLAAS_SERVICES_KUBE_CONTEXT) --namespace $(DLAAS_SERVICES_KUBE_NAMESPACE)

# The target host for the e2e test.
#DLAAS_HOST?=localhost:30001
DLAAS_HOST?=$(shell env DLAAS_KUBE_CONTEXT=$(DLAAS_SERVICES_KUBE_CONTEXT) ${MAINBIN_DIR}/kubecontext.sh restapi-url)

# The target host for the grpc cli.
DLAAS_GRPC?=$(shell env DLAAS_KUBE_CONTEXT=$(DLAAS_SERVICES_KUBE_CONTEXT) ${MAINBIN_DIR}/bin/kubecontext.sh trainer-url)

include ${AISPHERE_DIR}/ffdl-commons/ffdl-protoc.mk

# include ../ffdl-commons/ffdl-minikube.mk

vet:                                         ## go vet
	go vet $(shell glide nv)

lint:                                        ## Run the code linter
	go list ./... | grep -v /vendor/ | grep -v /grpc_trainer_v2 | xargs -L1 golint -set_exit_status

glide-update-base:                                ## Run full glide rebuild
	glide up;

glide-cache-clear:                           ## Run clear the glide cache
	glide cache-clear;

glide-clean:                                 ## Run full glide rebuild
	rm -rf vendor;

install-deps-local-commons:						 ## Install local ffdl-commons into vendor dir
	rsync -av ${AISPHERE_DIR}/${REPO_COMMONS} vendor/github.com/AISphere --exclude vendor --exclude .git --exclude .github

glide-install:                               ## Run full glide rebuild
	glide install

install-deps-base: glide-clean glide-install

install-deps-if-needed:
	@if [ ! -d "vendor" ]; then \
		make install-deps; \
	fi \

build-x86-64:                                ## Install dependencies if needed, compile go code
	@if [ ! -d "vendor" ]; then \
		if [ -f "glide.yaml" ]; then \
			make install-deps; \
		fi; \
	fi; \
	(CGO_ENABLED=0 GOOS=linux go build -ldflags "-s" -a -installsuffix cgo -o bin/main)

docker-build-only:
	(docker build --label git-commit=$(shell git rev-list -1 HEAD) -t "$(DOCKER_HOST_NAME)/$(DOCKER_NAMESPACE)/$(DOCKER_IMG_NAME):$(DLAAS_IMAGE_TAG)" .)

docker-build-base-only: install-deps-if-needed build-x86-64 docker-build-only

docker-build-base: install-deps-if-needed build-x86-64 docker-build-only

build: docker-build docker-push               ## -> Build and push images for current repo

docker-push-base:
	@if [ "${DOCKER_HOST_NAME}" = "docker.io" ]; then \
		if [[ -z "${DOCKER_REPO_USER}" ]] || [[ -z "${DOCKER_REPO_PASS}" ]] ; then \
			echo "Please define DOCKER_REPO_USER and DOCKER_REPO_PASS."; \
			exit 1; \
		else \
			docker login --username="${DOCKER_REPO_USER}" --password="${DOCKER_REPO_PASS}"; \
			docker push "$(DOCKER_HOST_NAME)/$(DOCKER_NAMESPACE)/$(DOCKER_IMG_NAME):$(DLAAS_IMAGE_TAG)"; \
		fi; \
	else \
		echo docker push "$(DOCKER_HOST_NAME)/$(DOCKER_NAMESPACE)/$(DOCKER_IMG_NAME):$(DLAAS_IMAGE_TAG)"; \
		docker push "$(DOCKER_HOST_NAME)/$(DOCKER_NAMESPACE)/$(DOCKER_IMG_NAME):$(DLAAS_IMAGE_TAG)"; \
	fi;

git-branch-status:                           ## Show this repos branch status
	@CURRENTPROJ=`basename $(shell pwd)`; \
	CURRENTBRANCH=`git branch | sed -n '/\* /s///p'`; \
	if [ "$$CURRENTBRANCH" != "master" ]; then \
		printf "# ------- %24s %s -------\n" "$$CURRENTBRANCH" "$$CURRENTPROJ"; \
		git status -s -uno; \
	fi

# GIT_FLAGS="--dry-run"
GIT_FLAGS ?= ""
MSG ?= "empty commit message"

git-commit-push:                             ## Show this repos branch status.  Put commit message in MSG environment variable.
	@CURRENTPROJ=`basename $(shell pwd)`; \
	CURRENTBRANCH=`git branch | sed -n '/\* /s///p'`; \
	if [ "$$CURRENTBRANCH" != "master" ]; then \
		printf "# ------- %24s %s -------\n" "$$CURRENTBRANCH" "$$CURRENTPROJ"; \
		git commit -a -m "${MSG}" ; \
		git push -f origin $$CURRENTBRANCH ; \
	fi

gen-certs-only:                              ## generate certificates
	cd ${AISPHERE_DIR}/${REPO_COMMONS}/certs ; \
	./generate.sh

install-certs:                               ## install certificates
	cd ${AISPHERE_DIR}/${REPO_COMMONS}/certs ; \
	for x in ${REPOS_ALL_CERT_REPOS}; do \
		dir=${AISPHERE_DIR}/$$x/certs; \
		echo copying certs into $${dir}; \
		mkdir -p $${dir}; \
		cp ca.crt $${dir}; \
		cp server.crt $${dir}; \
		cp server.key $${dir}; \
	done

gen-certs: gen-certs-only install-certs      ## generate and install certificates

del-certs:                                   ## delete all certificates
	@for x in ${REPOS_ALL_CERT_REPOS}; do \
		dir=${AISPHERE_DIR}/$$x/certs; \
		echo deleting certs from $${dir}; \
		rm -rf $${dir}; \
	done; \
	cd ${AISPHERE_DIR}/${REPO_COMMONS}/certs ; \
	rm -f ca.*; \
	rm -f client.*; \
	rm -f server.*

ensure-kubectl-installed:
ifeq (, $(shell which kubectl))
 	$(error "kubectl utility not found, please follow instructions at https://kubernetes.io/docs/tasks/tools/install-kubectl/ to install")
endif

cli-grpc-config: ensure-kubectl-installed  ## Show env vars needed to run gRPC cli
	@host=$(shell kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}'); \
	port=$(shell kubectl get svc/ffdl-trainer -o jsonpath='{.spec.ports[0].nodePort}' 2> /dev/null); \
	if [[ -z "$$host" || -z "$$port" ]]; then \
		url="localhost:30005"; \
	else \
		url="$$host:$$port"; \
	fi; \
	echo "# To use the DLaaS GRPC CLI, set the following environment variables:"; \
	echo "export DLAAS_USERID=user-$(WHOAMI)  # replace with your name"; \
	echo "export DLAAS_GRPC=$$url  # for the GRPC cli"

show-dirs:                                   ## Show directory vars used in the makefile, used by the Makefile
	@echo MAKEFILE_LIST=${MAKEFILE_LIST}
	@echo THIS_DIR=${THIS_DIR}
	@echo AISPHERE_DIR=${AISPHERE_DIR}
	@echo COMMONS_DIR=${COMMONS_DIR}

show-docker-vars:                            ## Show variables related to docker, used by the Makefile
	@echo DOCKER_IMG_NAME=${DOCKER_IMG_NAME}
	@echo DOCKER_HOST_NAME=${DOCKER_HOST_NAME}
	@echo DOCKER_REPO_USER=${DOCKER_REPO_USER}
	@echo DOCKER_REPO_PASS=${DOCKER_REPO_PASS}
	@echo DOCKER_NAMESPACE=${DOCKER_NAMESPACE}
	@echo DOCKER_PULL_POLICY=${DOCKER_PULL_POLICY}
	@echo DOCKER_IMG_NAME=${DOCKER_IMG_NAME}

show-repos:                                  ## Show variables that point to repo directories, used by the Makefile
	@echo REPOS_CORE_FFDL_SERVICE=${REPOS_CORE_FFDL_SERVICE}
	@echo REPOS_CORE_FFDL=${REPOS_CORE_FFDL}
	@echo REPOS_ALL_SERVICE=${REPOS_ALL_SERVICE}
	@echo REPOS_ALL_CERT_REPOS=${REPOS_ALL_CERT_REPOS}
	@echo REPOS_ALL_IN_ORG=${REPOS_ALL_IN_ORG}

all-lint:                                    ## Call vet and lint for all ffdl repos
	@for x in ${REPOS_CORE_FFDL}; do \
		echo lint ${AISPHERE_DIR}/$$x; \
		cd ${AISPHERE_DIR}/$$x; \
		make vet lint; \
	done

all-glide-update:                            ## Call glide-update for all ffdl repos
	@for x in ${REPOS_CORE_FFDL}; do \
		echo glide-update ${AISPHERE_DIR}/$$x; \
		cd ${AISPHERE_DIR}/$$x; \
		make glide-update; \
	done

all-install-deps-only:                            ## Call install-deps for all ffdl repos
	@for x in ${REPOS_CORE_FFDL}; do \
		echo install-deps ${AISPHERE_DIR}/$$x; \
		cd ${AISPHERE_DIR}/$$x; \
		make install-deps; \
	done

all-install-deps-local-commons:                    ## Copy local ffdl-commons into all vendor dirs.  Useful when testing local commons cases
	@for x in ${REPOS_CORE_FFDL}; do \
		echo install-deps ${AISPHERE_DIR}/$$x; \
		cd ${AISPHERE_DIR}/$$x; \
		make install-deps-local-commons; \
	done

all-install-deps:  all-install-deps-only all-install-deps-local-commons ## Call all-install-deps-basic and all-install-deps-local-commons

all-protoc:                    ## Create grpc proto clients for repos (via protoc)
	@for x in ${REPOS_CORE_FFDL}; do \
		echo install-deps ${AISPHERE_DIR}/$$x; \
		cd ${AISPHERE_DIR}/$$x; \
		make protoc; \
	done

all-docker-build:                            ## Call docker-build for ffdl repos
	@for x in ${REPOS_CORE_FFDL}; do \
		echo building ${AISPHERE_DIR}/$$x; \
		cd ${AISPHERE_DIR}/$$x; \
		make docker-build; \
	done

all-docker-push:                             ## Call docker-build for ffdl repos
	@for x in ${REPOS_CORE_FFDL}; do \
		echo pushing images for ${AISPHERE_DIR}/$$x; \
		cd ${AISPHERE_DIR}/$$x; \
		make docker-push; \
	done

all-build: all-docker-build all-docker-push  ## -> Build and push all services

all-git-branch-status:                       ## Show branch status of all repos
	@for x in ${REPOS_ALL}; do \
		cd ${AISPHERE_DIR}/$$x; \
		make git-branch-status; \
	done

all-git-commit-push:                         ## For all non-master branches, commit and push all repos to remote branch.  Put commit message in MSG environment variable.
	@for x in ${REPOS_ALL}; do \
		cd ${AISPHERE_DIR}/$$x; \
		make git-commit-push; \
	done

all-clean:                                   ## -> Clean artifacts from all ffdl repos
	@for x in ${REPOS_CORE_FFDL}; do \
		echo cleaning ${AISPHERE_DIR}/$$x; \
		cd ${AISPHERE_DIR}/$$x; \
		make clean; \
	done; \
	echo cleaning ${AISPHERE_DIR}/ffdl-commons; \
	cd ${AISPHERE_DIR}/ffdl-commons; \
	make clean

all: all-docker-build                        ## Build and (re)deploy everything

include ${AISPHERE_DIR}/ffdl-commons/ffdl-deploy.mk
include ${AISPHERE_DIR}/ffdl-commons/ffdl-test-simple.mk

# Credit to Dylan Tomas Meissner, per https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html comments
usage:                                       ## Show this help
	@cat $(MAKEFILE_LIST) | grep -e "^[a-zA-Z_\-]*: *.*## *" | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-32s\033[0m %s\n", $$1, $$2}'

#	@fgrep -h " ## " $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'

help: usage                                  ## -> Show make targets.  Primary targets flagged with "->"

clean-base:
	rm -rf vendor

.PHONY: all vet lint clean doctor usage	 test-unit
