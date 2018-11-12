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
# Scripts specific to minikube (and travis deploys)
# TODO: This makefile is mostly a placeholder right now!
#

ifeq ($(DOCKERHOST_HOST),localhost)
 # Check if minikube is active, otherwise leave it as 'localhost'
 MINIKUBE_IP := $(shell minikube ip 2>/dev/null)
 ifdef MINIKUBE_IP
  DOCKERHOST_HOST := $(MINIKUBE_IP)
 endif
endif

# ----- vars for travis testing -----

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

# ----- end vars for travis testing -----
