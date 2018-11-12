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
# Scripts specific to fast testing (as opposed to full end-to-end tests)
# TODO: This makefile is mostly a placeholder right now!
#

# Runs all unit tests (short tests)
test-unit:                                   ## Run unit tests
	DLAAS_LOGLEVEL=debug DLAAS_DNS_SERVER=disabled DLAAS_ENV=local go test $(TEST_PKGS) -v -short

test-integration:                            ## Run all integration tests (non-short tests with Integration in the name)
	DLAAS_LOGLEVEL=debug DLAAS_DNS_SERVER=disabled DLAAS_ENV=local  go test $(TEST_PKGS) -run "Integration" -v

test-base: test-unit test-integration

TEST_PKGS ?= $(shell go list ./... | grep -v /vendor/)

# Add a route on OS X to access docker instances directly
#
route-add-osx:
ifeq ($(shell uname -s),Darwin)
	sudo route -n add -net 172.17.0.0 $(DOCKERHOST_HOST)
endif

# Runs unit and integration tests
test: test-base
