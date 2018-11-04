#-------------------------------------------------------------
# IBM Confidential
# OCO Source Materials
# (C) Copyright IBM Corp. 2016
# The source code for this program is not published or
# otherwise divested of its trade secrets, irrespective of
# what has been deposited with the U.S. Copyright Office.
#-------------------------------------------------------------

GRPC_DIR = /go/src/github.ibm.com/deep-learning-platform/grpc-health-checker

install-deps:
	glide install

build-local: clean
	go build -o bin/grpc-health-checker

build-x86-64: clean
	CGO_ENABLED=0 GOOS=linux go build -ldflags "-s" -a -installsuffix cgo -o bin/grpc-health-checker

test:
	go test $(glide novendor) -v

clean:
	rm -rf bin/

build-in-docker:
	docker run -i --name grpc-health-checker --rm --volume $${PWD}:$(GRPC_DIR) -w $(GRPC_DIR) golang:latest sh -c "make install-deps build-x86-64 test"
