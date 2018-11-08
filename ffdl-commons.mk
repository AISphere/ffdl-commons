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
# Note the awkward name is to avoid clashing with the DOCKER_HOST variable.
DOCKERHOST_HOST ?= localhost

ifeq ($(DOCKERHOST_HOST),localhost)
 # Check if minikube is active, otherwise leave it as 'localhost'
 MINIKUBE_IP := $(shell minikube ip 2>/dev/null)
 ifdef MINIKUBE_IP
  DOCKERHOST_HOST := $(MINIKUBE_IP)
 endif
endif

FSWATCH := $(shell which fswatch 2>/dev/null)

WHOAMI ?= $(shell whoami)

KUBE_CURRENT_CONTEXT ?= $(shell kubectl config current-context)

# The environment where DLaaS is deployed.
# This affects a number of other variables below.
ifeq ($(KUBE_CURRENT_CONTEXT), minikube)
 # Automatically set to local if Kubernetes context is "minikube"
 DLAAS_ENV ?= local
 DLAAS_LCM_DEPLOYMENT ?= hybrid
else
 DLAAS_ENV ?= development
 DLAAS_LCM_DEPLOYMENT ?= development
endif

# Support two different Kuberentes clusters:
# - one to deploy the DLaaS microservices
# - one to deploy the learners and parameter servers.
DLAAS_SERVICES_KUBE_CONTEXT ?= $(KUBE_CURRENT_CONTEXT)
DLAAS_LEARNER_KUBE_CONTEXT ?= $(KUBE_CURRENT_CONTEXT)

# For non-local deployments, Kubernetes namespace
ifeq ($(DLAAS_ENV), local)
 export INVENTORY ?= ansible/envs/local/minikube.ini
 DLAAS_IMAGE_PULL_POLICY ?= IfNotPresent   # needed ?
 LCM_SERVICE_CPU_REQ ?= 100m               # needed ?
 LCM_SERVICE_MEMORY_REQ ?= 64Mi            # needed ?
else
 INVENTORY ?= ansible/envs/local/hybrid.ini
 DLAAS_IMAGE_PULL_POLICY ?= Always         # needed ?
 LCM_SERVICE_CPU_REQ ?= "1"                # needed ?
 LCM_SERVICE_MEMORY_REQ ?= 512Mi           # needed ?
endif

DLAAS_SERVICES_KUBE_NAMESPACE ?= $(shell env DLAAS_KUBE_CONTEXT=$(DLAAS_SERVICES_KUBE_CONTEXT) ./bin/kubecontext.sh namespace)
DLAAS_LEARNER_KUBE_NAMESPACE ?= $(shell env DLAAS_KUBE_CONTEXT=$(DLAAS_LEARNER_KUBE_CONTEXT) ./bin/kubecontext.sh namespace)
DLAAS_LEARNER_KUBE_URL ?= $(shell env DLAAS_KUBE_CONTEXT=$(DLAAS_LEARNER_KUBE_CONTEXT) ./bin/kubecontext.sh api-server)
DLAAS_LEARNER_KUBE_CAFILE ?= $(shell env DLAAS_KUBE_CONTEXT=$(DLAAS_LEARNER_KUBE_CONTEXT) ./bin/kubecontext.sh server-certificate)
DLAAS_LEARNER_KUBE_TOKEN ?= $(shell env DLAAS_KUBE_CONTEXT=$(DLAAS_LEARNER_KUBE_CONTEXT) ./bin/kubecontext.sh user-token)
DLAAS_LEARNER_KUBE_KEYFILE ?= $(shell env DLAAS_KUBE_CONTEXT=$(DLAAS_LEARNER_KUBE_CONTEXT) ./bin/kubecontext.sh client-key)
DLAAS_LEARNER_KUBE_CERTFILE ?= $(shell env DLAAS_KUBE_CONTEXT=$(DLAAS_LEARNER_KUBE_CONTEXT) ./bin/kubecontext.sh client-certificate)
DLAAS_LEARNER_KUBE_SECRET ?= kubecontext-$(DLAAS_LEARNER_KUBE_CONTEXT)

KUBE_SERVICES_CONTEXT_ARGS = --context $(DLAAS_SERVICES_KUBE_CONTEXT) --namespace $(DLAAS_SERVICES_KUBE_NAMESPACE)
KUBE_LEARNER_CONTEXT_ARGS = --context $(DLAAS_LEARNER_KUBE_CONTEXT) --namespace $(DLAAS_LEARNER_KUBE_NAMESPACE)

IMAGE_NAME_PREFIX = ffdl-
WHOAMI ?= $(shell whoami)
IMAGE_TAG ?= user-$(WHOAMI)
TEST_SAMPLE ?= tf-model
# VM_TYPE is "vagrant", "minikube" or "none"
VM_TYPE ?= minikube
HAS_STATIC_VOLUMES?=false
TEST_USER = test-user
SET_LOCAL_ROUTES ?= 0
MINIKUBE_RAM ?= 4096
MINIKUBE_CPUS ?= 3
MINIKUBE_DRIVER ?= hyperkit
MINIKUBE_BRIDGE ?= $(shell (ifconfig | grep -e "^bridge100:" || ifconfig | grep -e "^bridge0:") | sed 's/\(.*\):.*/\1/')
UI_REPO = git@github.com:IBM/FfDL-dashboard.git
CLI_CMD = $(shell pwd)/cli/bin/ffdl-$(UNAME_SHORT)
CLUSTER_NAME ?= mycluster
PUBLIC_IP ?= 127.0.0.1
CI_MINIKUBE_VERSION ?= v0.25.1
CI_KUBECTL_VERSION ?= v1.9.4
NAMESPACE ?= default

AWS_ACCESS_KEY_ID ?= test
AWS_SECRET_ACCESS_KEY ?= test
AWS_URL ?= http:\/\/s3\.default\.svc\.cluster\.local

# Use non-conflicting image tag, and Eureka name.
DLAAS_IMAGE_TAG ?= user-$(WHOAMI)
DLAAS_EUREKA_NAME ?= $(shell echo DLAAS-USER-$(WHOAMI) | tr '[:lower:]' '[:upper:]')

TRAINER_DOCKER_IMG_NAME ?= trainer-v2-service
LCM_DOCKER_IMG_NAME ?= lifecycle-manager-service
TDS_DOCKER_IMG_NAME ?= training-data-service
JOBMONITOR_NAME ?= jobmonitor

SERVICE_IMAGES ?= ${TRAINER_DOCKER_IMG_NAME} ${LCM_DOCKER_IMG_NAME} ${TDS_DOCKER_IMG_NAME} ${JOBMONITOR_NAME}

DOCKER_BX_NS ?= registry.ng.bluemix.net/dlaas_dev
DOCKER_REPO ?= ${DOCKER_BX_NS}
#DOCKER_REPO ?= docker.io
DOCKER_REPO_USER ?= user-test
DOCKER_REPO_PASS ?= test
DOCKER_REPO_DIR ?= ~/docker-registry/
DOCKER_NAMESPACE ?= ffdl
DOCKER_PULL_POLICY ?= IfNotPresent
DLAAS_LEARNER_REGISTRY ?= ${DOCKER_REPO}/${DOCKER_NAMESPACE}

## DOCKER_IMG_NAME must be set by enclosing Makefile.
DOCKER_IMG_NAME ?= "VALUE_MUST_BE_SET_BY_ENCLOSING_MAKEFILE!"

show_docker_vars:
	@echo DOCKER_IMG_NAME=${DOCKER_IMG_NAME}
	@echo DOCKER_BX_NS=${DOCKER_BX_NS}
	@echo DOCKER_REPO=${DOCKER_REPO}
	@echo DOCKER_REPO_USER=${DOCKER_REPO_USER}
	@echo DOCKER_REPO_PASS=${DOCKER_REPO_PASS}
	@echo DOCKER_REPO_DIR=${DOCKER_REPO_DIR}
	@echo DOCKER_NAMESPACE=${DOCKER_NAMESPACE}
	@echo DOCKER_PULL_POLICY=${DOCKER_PULL_POLICY}
	@echo DLAAS_LEARNER_REGISTRY=${DLAAS_LEARNER_REGISTRY}
	@echo DOCKER_IMG_NAME=${DOCKER_IMG_NAME}
	@echo SERVICE_IMAGES=${SERVICE_IMAGES}

REPOS_CORE_FFDL_SERVICE ?= ffdl-lcm ffdl-model-metrics ffdl-trainer
REPOS_CORE_FFDL ?= ${REPOS_CORE_FFDL_SERVICE} ffdl-job-monitor
REPOS_ALL_SERVICE ?= ${REPOS_CORE_FFDL_SERVICE} ffdl-rest-apis
REPOS_ALL ?= ${REPOS_CORE_FFDL} ffdl-commons ffdl-e2e-test ffdl-rest-apis

show_repos:
	@echo REPOS_CORE_FFDL_SERVICE=${REPOS_CORE_FFDL_SERVICE}
	@echo REPOS_CORE_FFDL=${REPOS_CORE_FFDL}
	@echo REPOS_ALL_SERVICE=${REPOS_ALL_SERVICE}
	@echo REPOS_ALL=${REPOS_ALL}

DLAAS_LEARNER_TAG?=dev_v8

# The target host for the e2e test.
#DLAAS_HOST?=localhost:30001
DLAAS_HOST?=$(shell env DLAAS_KUBE_CONTEXT=$(DLAAS_SERVICES_KUBE_CONTEXT) ./bin/kubecontext.sh restapi-url)

# The target host for the grpc cli.
DLAAS_GRPC?=$(shell env DLAAS_KUBE_CONTEXT=$(DLAAS_SERVICES_KUBE_CONTEXT) ./bin/kubecontext.sh trainer-url)

# Define environment variables for unit and integration testing
DLAAS_MONGO_PORT ?= 27017

#these credentials should be the same as what are present in lcm-secrets
DLAAS_ETCD_ADDRESS=https://watson-dev3-dal10-10.compose.direct:15232,https://watson-dev3-dal10-9.compose.direct:15232
DLAAS_ETCD_USERNAME=root
DLAAS_ETCD_PASSWORD=RHDACXYDLMIXXPEE
DLAAS_ETCD_PREFIX=/dlaas/jobs/local_hybrid/

LEARNER_DEPLOYMENT_ARGS = DLAAS_LEARNER_KUBE_URL=$(DLAAS_LEARNER_KUBE_URL) \
                          DLAAS_LEARNER_KUBE_TOKEN=$(DLAAS_LEARNER_KUBE_TOKEN) \
                          DLAAS_LEARNER_KUBE_KEYFILE=$(DLAAS_LEARNER_KUBE_KEYFILE) \
                          DLAAS_LEARNER_KUBE_CERTFILE=$(DLAAS_LEARNER_KUBE_CERTFILE) \
                          DLAAS_LEARNER_KUBE_CAFILE=$(DLAAS_LEARNER_KUBE_CAFILE) \
                          DLAAS_LEARNER_KUBE_NAMESPACE=$(DLAAS_LEARNER_KUBE_NAMESPACE) \
                          DLAAS_LEARNER_KUBE_SECRET=$(DLAAS_LEARNER_KUBE_SECRET)
DEPLOYMENT_ARGS = DLAAS_ENV=$(DLAAS_ENV) $(LEARNER_DEPLOYMENT_ARGS) \
                  DLAAS_LCM_DEPLOYMENT=$(DLAAS_LCM_DEPLOYMENT) \
                  DLAAS_IMAGE_TAG=$(DLAAS_IMAGE_TAG) \
                  DLAAS_LEARNER_TAG=$(DLAAS_LEARNER_TAG) \
                  DLAAS_IMAGE_PULL_POLICY=$(DLAAS_IMAGE_PULL_POLICY) \
                  LCM_SERVICE_CPU_REQ=$(LCM_SERVICE_CPU_REQ) \
                  LCM_SERVICE_MEMORY_REQ=$(LCM_SERVICE_MEMORY_REQ) \
                  DLAAS_ETCD_ADDRESS=$(DLAAS_ETCD_ADDRESS) \
				  DLAAS_ETCD_PREFIX=$(DLAAS_ETCD_PREFIX) \
				  DLAAS_ETCD_USERNAME=$(DLAAS_ETCD_USERNAME) \
				  DLAAS_ETCD_PASSWORD=$(DLAAS_ETCD_PASSWORD) \
				  DLAAS_MOUNTCOS_GB_CACHE_PER_GPU=$(DLAAS_MOUNTCOS_GB_CACHE_PER_GPU)

BUILD_DIR=build

THIS_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
AISPHERE_DIR ?= $(shell dirname "$(THIS_DIR)")

show_dirs:
	@echo MAKEFILE_LIST=${MAKEFILE_LIST}
	@echo THIS_DIR=${THIS_DIR}
	@echo AISPHERE_DIR=${AISPHERE_DIR}

usage:              ## Show this help
	@fgrep -h " ## " $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'

TRAINER_REPO ?= raw.githubusercontent.com/sboagibm/ffdl-trainer
TRAINER_VERSION ?= proto-only-depend
TRAINER_LOCATION ?= vendor/github.com/AISphere/ffdl-trainer
TRAINER_SUBDIR ?= trainer/grpc_trainer_v2
TRAINER_SUBDIR_IN ?= trainer/grpc_trainer_v2
TRAINER_FNAME ?= trainer

# LCM_REPO ?= raw.githubusercontent.com/AISphere/ffdl-lcm
LCM_REPO ?= raw.githubusercontent.com/sboagibm/ffdl-lcm
LCM_VERSION ?= branch2
LCM_LOCATION ?= vendor/github.com/AISphere/ffdl-lcm
LCM_SUBDIR ?= service
LCM_SUBDIR_IN ?= service/grpc_training_data_v1
LCM_FNAME ?= lcm

TDS_REPO ?= raw.githubusercontent.com/AISphere/ffdl-model-metrics
TDS_VERSION ?= 7ff38aaa21a47c354b7c64dde79dc88ff4372b1e
TDS_LOCATION ?= vendor/github.com/AISphere/ffdl-model-metrics
TDS_SUBDIR ?= service/grpc_training_data_v1
TDS_FNAME ?= training_data

protoc-trainer:  ## Make the trainer protoc client, depends on `make glide` being run first
	#	rm -rf $(TRAINER_LOCATION)/$(TRAINER_SUBDIR)
	wget https://$(TRAINER_REPO)/$(TRAINER_VERSION)/$(TRAINER_SUBDIR_IN)/$(TRAINER_FNAME).proto -P $(TRAINER_LOCATION)/$(TRAINER_SUBDIR)
	wget https://$(TRAINER_REPO)/$(TRAINER_VERSION)/client/client.go -P $(TRAINER_LOCATION)/client
	wget https://$(TRAINER_REPO)/$(TRAINER_VERSION)/client/jobstatus_client.go -P $(TRAINER_LOCATION)/client
	wget https://$(TRAINER_REPO)/$(TRAINER_VERSION)/client/training_status.go -P $(TRAINER_LOCATION)/client
	cd ./$(TRAINER_LOCATION); \
	protoc -I./$(TRAINER_SUBDIR) --go_out=plugins=grpc:$(TRAINER_SUBDIR) ./$(TRAINER_SUBDIR)/$(TRAINER_FNAME).proto
	@# At the time of writing, protoc does not support custom tags, hence use a little regex to add "bson:..." tags
	@# See: https://github.com/golang/protobuf/issues/52
	cd $(TRAINER_LOCATION); \
	sed -i .bak '/.*bson:.*/! s/json:"\([^"]*\)"/json:"\1" bson:"\1"/' ./$(TRAINER_SUBDIR)/$(TRAINER_FNAME).pb.go

protoc-lcm:  ## Make the lcm protoc client, depends on `make glide` being run first
	#	rm -rf $(LCM_LOCATION)/$(LCM_SUBDIR)
	wget https://$(LCM_REPO)/$(LCM_VERSION)/$(LCM_SUBDIR_IN)/$(LCM_FNAME).proto -P $(LCM_LOCATION)/$(LCM_SUBDIR)
	wget https://$(LCM_REPO)/$(LCM_VERSION)/service/grpc_training_data_v1/client/lcm.go -P $(LCM_LOCATION)/service/grpc_training_data_v1/client
	wget https://$(LCM_REPO)/$(LCM_VERSION)/service/grpc_training_data_v1/lifecycle.go -P $(LCM_LOCATION)/service/grpc_training_data_v1
	wget https://$(LCM_REPO)/$(LCM_VERSION)/lcmconfig/lcmconfig.go -P $(LCM_LOCATION)/lcmconfig
	wget https://$(LCM_REPO)/$(LCM_VERSION)/coord/coord.go -P $(LCM_LOCATION)/coord
	cd ./$(LCM_LOCATION); \
	protoc -I./$(LCM_SUBDIR) --go_out=plugins=grpc:$(LCM_SUBDIR) ./$(LCM_SUBDIR)/$(LCM_FNAME).proto
	@# At the time of writing, protoc does not support custom tags, hence use a little regex to add "bson:..." tags
	@# See: https://github.com/golang/protobuf/issues/52
	cd $(LCM_LOCATION); \
	sed -i .bak '/.*bson:.*/! s/json:"\([^"]*\)"/json:"\1" bson:"\1"/' ./$(LCM_SUBDIR)/$(LCM_FNAME).pb.go

protoc-tds:  ## Make the training-data service protoc client, depends on `make glide` being run first
	rm -rf $(TDS_LOCATION)/$(TDS_SUBDIR)
	wget https://$(TDS_REPO)/$(TDS_VERSION)/$(TDS_SUBDIR)/$(TDS_FNAME).proto -P $(TDS_LOCATION)/$(TDS_SUBDIR)
	cd ./$(TDS_LOCATION); \
	protoc -I./$(TDS_SUBDIR) --go_out=plugins=grpc:$(TDS_SUBDIR) ./$(TDS_SUBDIR)/$(TDS_FNAME).proto
	@# At the time of writing, protoc does not support custom tags, hence use a little regex to add "bson:..." tags
	@# See: https://github.com/golang/protobuf/issues/52
	cd $(TDS_LOCATION); \
	sed -i .bak '/.*bson:.*/! s/json:"\([^"]*\)"/json:"\1" bson:"\1"/' ./$(TDS_SUBDIR)/$(TDS_FNAME).pb.go

vet:
	go vet $(shell glide nv)

lint:               ## Run the code linter
	go list ./... | grep -v /vendor/ | grep -v /grpc_trainer_v2 | xargs -L1 golint -set_exit_status

glide-update:               ## Run full glide rebuild
	glide up; \

glide-clean:               ## Run full glide rebuild
	glide cache-clear; \
	rm -rf vendor;

glide-install:               ## Run full glide rebuild
	glide install

install-deps: glide-update glide-clean glide-install

build-grpc-health-checker:
	(cd vendor/github.com/AISphere/ffdl-commons/grpc-health-checker && make build-x86-64)

kube-artifacts:    ## Show the state of various Kubernetes artifacts
	kubectl $(KUBE_SERVICES_CONTEXT_ARGS) get pod,configmap,svc,ing,statefulset,job,pvc,deploy,secret -o wide --show-all
	#@echo; echo
	#kubectl $(KUBE_LEARNER_CONTEXT_ARGS) get deploy,statefulset,pod,pvc -o wide --show-all

kube-destroy:
	@echo "If you're sure you want to delete the $(DLAAS_SERVICES_KUBE_NAMESPACE)" namespace, run the following command:
	@echo "  kubectl $(KUBE_SERVICES_CONTEXT_ARGS) delete namespace $(DLAAS_SERVICES_KUBE_NAMESPACE)"

docker-build-x: build-x86-64
	cd vendor/github.com/AISphere/ffdl-commons/grpc-health-checker && make build-x86-64
	(docker build --label git-commit=$(shell git rev-list -1 HEAD) -t "$(DOCKER_BX_NS)/$(DOCKER_IMG_NAME):$(DLAAS_IMAGE_TAG)" .)

docker-build-all:
	@for x in ${REPOS_CORE_FFDL}; do \
		echo building ${AISPHERE_DIR}/$$x; \
		cd ${AISPHERE_DIR}/$$x; \
		make install-deps protoc docker-build-x; \
	done

clean-all:
	@for x in ${REPOS_CORE_FFDL}; do \
		echo cleaning ${AISPHERE_DIR}/$$x; \
		cd ${AISPHERE_DIR}/$$x; \
		rm ffdl-commons.mk
		make clean-base; \
	done

clean-base:
	rm -rf vendor

.PHONY: all vet lint clean doctor usage showvars test-unit
