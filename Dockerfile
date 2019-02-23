#-------------------------------------------------------------
# IBM Confidential
# OCO Source Materials
# (C) Copyright IBM Corp. 2016
# The source code for this program is not published or
# otherwise divested of its trade secrets, irrespective of
# what has been deposited with the U.S. Copyright Office.
#-------------------------------------------------------------

FROM ubuntu:16.04

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install --yes ca-certificates curl ldnsutils

ADD grpc-health-checker/bin/grpc-health-checker /usr/local/bin/
RUN chmod +x /usr/local/bin/grpc-health-checker
