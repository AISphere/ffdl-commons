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
# Deploy and undeploy services.  Assume import by ffdl-commons.mk
#

TILLER_NAMESPACE ?= ${DLAAS_SERVICES_KUBE_NAMESPACE}
ROOT_DEPLOY_DIR := ${AISPHERE_DIR}/${REPO_TRAINER}
ENV_DIR ?= ${ROOT_DEPLOY_DIR}/envs
FFDL_DEPLOY_VALUES_FILENAME ?= dev_values.yaml
FFDL_DEPLOY_VALUES ?= ${ENV_DIR}/${FFDL_DEPLOY_VALUES_FILENAME}
HELM_FLAGS ?=
HELM_DEPLOY_DIR := ${ROOT_DEPLOY_DIR}/helmdeploy

show-helm-vars:       ## Show main helm vars
	@echo HELM_DEPLOY_DIR: ${HELM_DEPLOY_DIR}; \
	echo TILLER_NAMESPACE: ${TILLER_NAMESPACE}; \
	echo DOCKER_REPO: ${DOCKER_REPO}; \
	echo DOCKER_PULL_POLICY: ${DOCKER_PULL_POLICY}

deploy: show-helm-vars       ## -> Deploy the services to Kubernetes
	@# deploy the stack via helm
	@echo Deploying services to Kubernetes. This may take a while.
	@if ! helm list --tiller-namespace ${TILLER_NAMESPACE} > /dev/null 2>&1; then \
		echo 'Installing helm/tiller'; \
		helm init --tiller-namespace ${TILLER_NAMESPACE} > /dev/null 2>&1; \
		sleep 3; \
	fi;
	@echo collecting existing pods
	@while kubectl get pods | \
		grep -v RESTARTS | \
		grep -v Running | \
		grep 'alertmanager\|etcd0\|lcm\|restapi\|trainer\|trainingdata\|ui\|mongo\|prometheus\|pushgateway\|storage' > /dev/null; \
	do \
		sleep 1; \
	done
	@echo finding out which pods are running
	@while ! (kubectl get pods | grep tiller-deploy | grep '1/1' > /dev/null); \
	do \
		sleep 1; \
	done
	@echo calling big command
	@set -o verbose; \
		cd ${ROOT_DEPLOY_DIR}; \
		echo HELM_DEPLOY_DIR: ${HELM_DEPLOY_DIR}; \
		helm dependency update; \
		mkdir -p ${HELM_DEPLOY_DIR}; \
		cp -rf Chart.yaml values.yaml charts templates ${HELM_DEPLOY_DIR}; \
		existing=$$(helm list --tiller-namespace ${TILLER_NAMESPACE} | grep ffdl | awk '{print $$1}' | head -n 1); \
		(if [ -z "$$existing" ]; then \
			echo "Deploying the stack via Helm. This will take a while."; \
			echo helm install ${HELM_FLAGS} --tiller-namespace ${TILLER_NAMESPACE} -f $(FFDL_DEPLOY_VALUES) ${HELM_DEPLOY_DIR}; \
			helm install ${HELM_FLAGS} --tiller-namespace ${TILLER_NAMESPACE} -f $(FFDL_DEPLOY_VALUES) ${HELM_DEPLOY_DIR} ; \
			sleep 10; \
		else \
			echo "Upgrading existing Helm deployment ($$existing). This will take a while."; \
			echo helm --debug upgrade --tiller-namespace ${TILLER_NAMESPACE} -f $(FFDL_DEPLOY_VALUES) $$existing ${HELM_DEPLOY_DIR} ; \
			helm ${HELM_FLAGS} upgrade --tiller-namespace ${TILLER_NAMESPACE} -f $(FFDL_DEPLOY_VALUES) $$existing ${HELM_DEPLOY_DIR} ; \
		fi) & pid=$$!; \
		sleep 5; \
		while kubectl get pods | \
			grep -v RESTARTS | \
			grep -v Running | \
			grep 'alertmanager\|etcd0\|lcm\|restapi\|trainer\|trainingdata\|ui\|mongo\|prometheus\|pushgateway\|storage'; \
		do \
			sleep 5; \
		done
		@for i in $$(seq 1 10); do \
			existing=$$(helm list --tiller-namespace ${TILLER_NAMESPACE} | grep ffdl | awk '{print $$1}' | head -n 1); \
			if [ ! -z "$$existing" ]; then \
				status=`helm status --tiller-namespace ${TILLER_NAMESPACE} $$existing | grep STATUS:`; \
				echo $$status; \
				if echo "$$status" | grep "DEPLOYED" > /dev/null; then \
					kill $$pid > /dev/null 2>&1; \
					exit 0; \
				fi; \
			else \
				printf "."; \
			fi; \
			sleep 3; \
		done; \
		exit 0
	@echo done with big command
	@echo Initializing...
	@# wait for pods to be ready
	@while kubectl get pods | \
		grep -v RESTARTS | \
		grep -v Running | \
		grep 'alertmanager\|etcd0\|lcm\|restapi\|trainer\|trainingdata\|ui\|mongo\|prometheus\|pushgateway\|storage' > /dev/null; \
	do \
		sleep 5; \
	done
	# @echo initialize monitoring dashboards
	# @if [ "$$CI" != "true" ]; then bin/grafana.init.sh; fi
	@echo
	@echo System status:
	@make status

undeploy:                    ## Undeploy the services from Kubernetes
	@# undeploy the stack
	@existing=$$(helm list --tiller-namespace ${TILLER_NAMESPACE} | grep ffdl | awk '{print $$1}' | head -n 1); \
		(if [ ! -z "$$existing" ]; then echo "Undeploying the stack via helm. This may take a while."; helm delete --tiller-namespace ${TILLER_NAMESPACE} "$$existing"; echo "The stack has been undeployed."; fi) > /dev/null;

$(addprefix undeploy-, $(SERVICES)): undeploy-%: %
	@SERVICE_NAME=$< make .undeploy-service

.undeploy-service:
	@echo deleting $(SERVICE_NAME)
	(kubectl delete deploy,svc,statefulset --selector=service="ffdl-$(SERVICE_NAME)")

rebuild-and-deploy-lcm: build-lcm docker-build-lcm undeploy-lcm deploy

rebuild-and-deploy-trainer: build-trainer docker-build-trainer undeploy-trainer deploy

status:                      ## Print the current system status and service endpoints
	@tiller=s; \
		status_kube=$$(kubectl config current-context) && status_kube="Running (context '$$status_kube')" || status_kube="n/a"; \
		echo "Kubernetes:\t$$status_kube"; \
		node_ip=$$(make --no-print-directory kubernetes-ip); \
		status_tiller=$$(helm list --tiller-namespace ${TILLER_NAMESPACE} 2> /dev/null) && status_tiller="Running" || status_tiller="n/a"; \
		echo "Helm/Tiller:\t$$status_tiller"; \
		status_ffdl=$$(helm --tiller-namespace ${TILLER_NAMESPACE} list 2> /dev/null | grep ffdl | awk '{print $$1}' | head -n 1) && status_ffdl="Running ($$(helm status --tiller-namespace ${TILLER_NAMESPACE} "$$status_ffdl" 2> /dev/null | grep STATUS:))" || status_ffdl="n/a"; \
		echo "FfDL Services:\t$$status_ffdl"; \
		port_api=$$(kubectl get service ffdl-restapi -o jsonpath='{.spec.ports[0].nodePort}' 2> /dev/null) && status_api="Running (http://$$node_ip:$$port_api)" || status_api="n/a"; \
		echo "REST API:\t$$status_api"; \
		port_ui=$$(kubectl get service ffdl-ui -o jsonpath='{.spec.ports[0].nodePort}' 2> /dev/null) && status_ui="Running (http://$$node_ip:$$port_ui/#/login?endpoint=$$node_ip:$$port_api&username=test-user)" || status_ui="n/a"; \
		echo "Web UI:\t\t$$status_ui"; \
		status_grafana=$$(kubectl get service grafana -o jsonpath='{.spec.ports[0].nodePort}' 2> /dev/null) && status_grafana="Running (http://$$node_ip:$$status_grafana) (login: admin/admin)" || status_grafana="n/a"; \
		echo "Grafana:\t$$status_grafana"

# VM_TYPE is "vagrant", "minikube" or "none"
VM_TYPE ?= none
PUBLIC_IP ?= 127.0.0.1

kubernetes-ip:
	@if [ "$$CI" = "true" ]; then kubectl get nodes -o jsonpath='{ .items[0].status.addresses[?(@.type=="InternalIP")].address }'; \
		elif [ "$(VM_TYPE)" = "vagrant" ]; then \
			node_ip_line=$$(vagrant ssh master -c 'ifconfig eth1 | grep "inet "' 2> /dev/null); \
			node_ip=$$(echo $$node_ip_line | sed "s/.*inet \([^ ]*\) .*/\1/"); \
			echo $$node_ip; \
		elif [ "$(VM_TYPE)" = "minikube" ]; then \
			echo $$(minikube ip); \
		elif [ "$(VM_TYPE)" = "ibmcloud" ]; then \
			echo $$(bx cs workers $(CLUSTER_NAME) | grep Ready | awk '{ print $$2;exit }'); \
		elif [ "$(VM_TYPE)" = "none" ]; then \
			echo "$(PUBLIC_IP)"; \
		else \
			echo "$(PUBLIC_IP)"; \
		fi
