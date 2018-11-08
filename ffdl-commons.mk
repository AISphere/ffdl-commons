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

DOCKER_BX_NS ?= registry.ng.bluemix.net/dlaas_dev
DOCKER_BASE_IMG_NAME=dlaas-service-base
DOCKER_BASE_IMG_TAG=ubuntu16.04
SWAGGER_FILE=api/swagger/swagger.yml

DOCKER_IMG_NAME=lifecycle-manager-service

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

# Use non-conflicting image tag, and Eureka name.
DLAAS_IMAGE_TAG ?= user-$(WHOAMI)
DLAAS_EUREKA_NAME ?= $(shell echo DLAAS-USER-$(WHOAMI) | tr '[:lower:]' '[:upper:]')

DLAAS_LEARNER_TAG?=dev_v8

# The target host for the e2e test.
#DLAAS_HOST?=localhost:30001
DLAAS_HOST?=$(shell env DLAAS_KUBE_CONTEXT=$(DLAAS_SERVICES_KUBE_CONTEXT) ./bin/kubecontext.sh restapi-url)

# The target host for the grpc cli.
DLAAS_GRPC?=$(shell env DLAAS_KUBE_CONTEXT=$(DLAAS_SERVICES_KUBE_CONTEXT) ./bin/kubecontext.sh trainer-url)

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

build-grpc-health-checker:
	(cd vendor/github.com/AISphere/ffdl-commons/grpc-health-checker && make build-x86-64)

protoc-trainer:  ## Make the trainer protoc client, depends on `make glide` being run first
	#	rm -rf $(TRAINER_LOCATION)/$(TRAINER_SUBDIR)
	wget https://$(TRAINER_REPO)/$(TRAINER_VERSION)/$(TRAINER_SUBDIR_IN)/$(TRAINER_FNAME).proto -P $(TRAINER_LOCATION)/$(TRAINER_SUBDIR)
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

install-deps: glide-update glide-clean glide-install

# Hello, this is a change.
