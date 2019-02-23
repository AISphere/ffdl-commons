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
# Build protoc clients.  Assume import by ffdl-commons.mk
#

TRAINER_LOCATION ?= vendor/github.com/AISphere/${REPO_TRAINER}
TRAINER_SUBDIR ?= trainer/grpc_trainer_v2
TRAINER_SUBDIR_IN ?= trainer/grpc_trainer_v2
TRAINER_FNAME ?= trainer

LCM_LOCATION ?= vendor/github.com/AISphere/${REPO_LCM}
LCM_SUBDIR ?= service
LCM_SUBDIR_IN ?= service
LCM_FNAME ?= lcm

TDS_LOCATION ?= vendor/github.com/AISphere/${REPO_TDS}
TDS_SUBDIR ?= service/grpc_training_data_v1
TDS_FNAME ?= training_data

RELATIVE_REPO_TRAINER ?= ../$(REPO_TRAINER)
RELATIVE_REPO_LCM ?= ../$(REPO_LCM)
RELATIVE_REPO_TDS ?= ../$(REPO_TDS)

ensure-protoc-installed:
ifeq (, $(shell which protoc))
 	$(error "protoc utility not found, please follow instructions at http://google.github.io/proto-lens/installing-protoc.html to install")
endif
ifeq (, $(shell which protoc-gen-go))
 	$(error "protoc-gen-go plugin not found, please follow instructions at https://github.com/golang/protobuf#installation to install")
endif
	@echo "protoc and protoc-gen-go installed!"

show-protoc-dirs:                            ## Show directory vars used for protoc scripts
	@echo TRAINER_LOCATION=${TRAINER_LOCATION}
	@echo TRAINER_SUBDIR=${TRAINER_SUBDIR}
	@echo TRAINER_SUBDIR_IN=${TRAINER_SUBDIR_IN}
	@echo TRAINER_FNAME=${TRAINER_FNAME}
	@echo LCM_LOCATION=${LCM_LOCATION}
	@echo LCM_FNAME=${LCM_FNAME}
	@echo LCM_SUBDIR=${LCM_SUBDIR}
	@echo LCM_SUBDIR_IN=${LCM_SUBDIR_IN}
	@echo TDS_LOCATION=${TDS_LOCATION}
	@echo TDS_SUBDIR=${TDS_SUBDIR}
	@echo TDS_FNAME=${TDS_FNAME}

protoc-trainer: ensure-protoc-installed  ## Make the trainer protoc client, depends on `make glide` being run first
	mkdir -p $(TRAINER_LOCATION)/$(TRAINER_SUBDIR) && cp $(RELATIVE_REPO_TRAINER)/$(TRAINER_SUBDIR_IN)/$(TRAINER_FNAME).proto $(TRAINER_LOCATION)/$(TRAINER_SUBDIR)
	mkdir -p $(TRAINER_LOCATION)/client && cp $(RELATIVE_REPO_TRAINER)/client/client.go $(TRAINER_LOCATION)/client
	mkdir -p $(TRAINER_LOCATION)/client && cp $(RELATIVE_REPO_TRAINER)/client/jobstatus_client.go $(TRAINER_LOCATION)/client
	mkdir -p $(TRAINER_LOCATION)/client && cp $(RELATIVE_REPO_TRAINER)/client/training_status.go $(TRAINER_LOCATION)/client
	cd ./$(TRAINER_LOCATION); \
	protoc -I./$(TRAINER_SUBDIR) --go_out=plugins=grpc:$(TRAINER_SUBDIR) ./$(TRAINER_SUBDIR)/$(TRAINER_FNAME).proto
	@# At the time of writing, protoc does not support custom tags, hence use a little regex to add "bson:..." tags
	@# See: https://github.com/golang/protobuf/issues/52
	cd $(TRAINER_LOCATION); \
	sed -i.bak '/.*bson:.*/! s/json:"\([^"]*\)"/json:"\1" bson:"\1"/' ./$(TRAINER_SUBDIR)/$(TRAINER_FNAME).pb.go

protoc-lcm:  ensure-protoc-installed  ## Make the lcm protoc client, depends on `make glide` being run first
	mkdir -p $(LCM_LOCATION)/$(LCM_SUBDIR) && cp $(RELATIVE_REPO_LCM)/$(LCM_SUBDIR_IN)/$(LCM_FNAME).proto $(LCM_LOCATION)/$(LCM_SUBDIR)
	mkdir -p $(LCM_LOCATION)/service/client && cp $(RELATIVE_REPO_LCM)/service/client/lcm.go $(LCM_LOCATION)/service/client
	mkdir -p $(LCM_LOCATION)/service && cp $(RELATIVE_REPO_LCM)/service/lifecycle.go $(LCM_LOCATION)/service
	mkdir -p $(LCM_LOCATION)/lcmconfig && cp $(RELATIVE_REPO_LCM)/lcmconfig/lcmconfig.go $(LCM_LOCATION)/lcmconfig
	mkdir -p $(LCM_LOCATION)/coord && cp $(RELATIVE_REPO_LCM)/coord/coord.go $(LCM_LOCATION)/coord
	cd ./$(LCM_LOCATION); \
	protoc -I./$(LCM_SUBDIR) --go_out=plugins=grpc:$(LCM_SUBDIR) ./$(LCM_SUBDIR)/$(LCM_FNAME).proto
	@# At the time of writing, protoc does not support custom tags, hence use a little regex to add "bson:..." tags
	@# See: https://github.com/golang/protobuf/issues/52
	cd $(LCM_LOCATION); \
	sed -i.bak '/.*bson:.*/! s/json:"\([^"]*\)"/json:"\1" bson:"\1"/' ./$(LCM_SUBDIR)/$(LCM_FNAME).pb.go

protoc-tds:  ensure-protoc-installed  ## Make the training-data service protoc client, depends on `make glide` being run first
	mkdir -p $(TDS_LOCATION)/client && cp $(RELATIVE_REPO_TDS)/client/client.go $(TDS_LOCATION)/client
	mkdir -p $(TDS_LOCATION)/$(TDS_SUBDIR) && cp $(RELATIVE_REPO_TDS)/$(TDS_SUBDIR)/$(TDS_FNAME).proto $(TDS_LOCATION)/$(TDS_SUBDIR)
	cd ./$(TDS_LOCATION); \
	protoc -I./$(TDS_SUBDIR) --go_out=plugins=grpc:$(TDS_SUBDIR) ./$(TDS_SUBDIR)/$(TDS_FNAME).proto
	@# At the time of writing, protoc does not support custom tags, hence use a little regex to add "bson:..." tags
	@# See: https://github.com/golang/protobuf/issues/52
	cd $(TDS_LOCATION); \
	sed -i.bak '/.*bson:.*/! s/json:"\([^"]*\)"/json:"\1" bson:"\1"/' ./$(TDS_SUBDIR)/$(TDS_FNAME).pb.go


.PHONY: protoc-trainer protoc-lcm protoc-tds show-protoc-dirs
