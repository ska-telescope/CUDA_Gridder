# install CUDA support
# https://www.pugetsystems.com/labs/hpc/How-To-Install-CUDA-10-1-on-Ubuntu-19-04-1405/
# https://developer.nvidia.com/cuda-downloads?target_os=Linux&target_arch=x86_64&target_distro=Ubuntu&target_version=1804&target_type=runfilelocal

# Set dir of Makefile to a variable to use later
MAKEPATH := $(abspath $(lastword $(MAKEFILE_LIST)))
BASEDIR := $(patsubst %/,%,$(dir $(MAKEPATH)))

# Cross platform make declarations
# \
!ifndef 0 # \
# nmake code here \
MKDIR=mkdir # \
RMRF=del /f /s /q # \
!else
# make code here
MKDIR=mkdir -p
RMRF=rm -rf
# \
!endif

# Where are we going to configure cmake to run
BUILDDIR := $(BASEDIR)/build
RUNDIR := $(BASEDIR)/app
TESTDIR := $(BASEDIR)/gridder_test_data
NUM_VISIBILITIES ?= 2000000
GRIDDER := gridder
RUNTIME ?= nvidia ## Docker runtime
BUILD_TYPE ?= Debug ## build type: Debug or Release
BUILD_TESTS ?= OFF ## cmake enable tests
# CLANG_PP ?= clang++-8 ## which installed version of clang++

# Args for Base Images from https://hub.docker.com/r/nvidia/cuda/
NVIDIA_BASE_IMAGE ?= nvidia/cuda:10.1-devel
NVIDIA_RUNTIME_IMAGE ?= nvidia/cuda:10.1-runtime

NAME := cuda-gridder
KUBE_NAMESPACE ?= "default"
KUBECTL_VERSION ?= latest
HELM_VERSION ?= v2.14.0
HELM_CHART = $(NAME)
HELM_RELEASE ?= test
CI_REGISTRY ?= docker.io
CI_REPOSITORY ?= piersharding
TAG ?= latest
IMAGE ?= $(CI_REPOSITORY)/$(NAME):$(TAG)
REPLICAS := 1

# define your personal overides for above variables in here
-include PrivateRules.mak

.PHONY: vars help cmake test clean build run up down k8s show lint deploy delete logs describe namespace
.DEFAULT_GOAL := help

vars: ## cmake variables
	@echo "BASEDIR: $(BASEDIR)"
	@echo "BUILDDIR: $(BUILDDIR)"
	@echo "RUNDIR: $(RUNDIR)"
	@echo "TESTDIR: $(TESTDIR)"
	@echo "NUM_VISIBILITIES: $(NUM_VISIBILITIES)"

cmake: vars ## bootstrap git submodules and cmake in BUILDDIR
	@if [ -d "$(BUILDDIR)" ]; then \
	  echo "BUILDDIR already exists - aborting"; \
		exit 1; \
	fi
	git submodule update --init --recursive
	$(MKDIR) $(BUILDDIR)
	cd $(BUILDDIR) && cmake -DCMAKE_BUILD_TYPE=$(BUILD_TYPE) $(BASEDIR)

build: cmake ## build GRIDDER
	cd $(BUILDDIR) && $(MAKE)
	$(MKDIR) $(RUNDIR)
	cp -f $(BUILDDIR)/$(GRIDDER) $(RUNDIR)/$(GRIDDER)

test_data:
	@if [ -d "$(TESTDIR)" ]; then \
	echo "$(TESTDIR) already exists - aborting"; \
	exit 1; \
	fi
	$(MKDIR) $(TESTDIR)
	cd $(TESTDIR) && (for i in ../*.zip; do unzip $$i; done)
	cd $(TESTDIR) && perl -i -ne 'if ($$_ =~ /^31395840/) { print "$(NUM_VISIBILITIES)\n" } else { print $$_ } ' el82-70.txt
	cd $(TESTDIR) && head -5 el82-70.txt

run: ## run GRIDDER
	cd $(RUNDIR) && ./$(GRIDDER)

test: ## test GRIDDER image
	docker run --rm  --gpus all -ti -v $$(pwd)/gridder_test_data:/gridder_test_data $(IMAGE)

clean_test_data: ## clean (remove) TESTDIR
	$(RMRF) $(TESTDIR)

clean: ## clean (remove) BUILDDIR GRIDDER
	$(RMRF) $(BUILDDIR) $(RUNDIR)

image: ## build Docker image
	docker build \
	  --build-arg NVIDIA_BASE_IMAGE=$(NVIDIA_BASE_IMAGE) \
		--build-arg NVIDIA_RUNTIME_IMAGE=$(NVIDIA_RUNTIME_IMAGE) \
	  -t $(NAME):latest -f Dockerfile .

tag: image ## tag image
	docker tag $(NAME):latest $(IMAGE)

push: tag ## push image
	docker push $(IMAGE)

up: ## start the docker-compose test service
	IMAGE=$(IMAGE) RUNTIME=$(RUNTIME) docker-compose up

down: ## cleanup the docker-compose test service
	IMAGE=$(IMAGE) RUNTIME=$(RUNTIME) docker-compose down

k8s: ## Which kubernetes are we connected to
	@echo "Kubernetes cluster-info:"
	@kubectl cluster-info
	@echo ""
	@echo "kubectl version:"
	@kubectl version
	@echo ""
	@echo "Helm version:"
	@helm version --client
	@echo ""
	@echo "Helm plugins:"
	@helm plugin list

logs: ## show gridder POD logs
	@for i in `kubectl -n $(KUBE_NAMESPACE) get pods -l app.kubernetes.io/instance=$(HELM_RELEASE) -o=name`; \
	do \
	echo "---------------------------------------------------"; \
	echo "Logs for $${i}"; \
	echo kubectl -n $(KUBE_NAMESPACE) logs $${i}; \
	echo kubectl -n $(KUBE_NAMESPACE) get $${i} -o jsonpath="{.spec.initContainers[*].name}"; \
	echo "---------------------------------------------------"; \
	for j in `kubectl -n $(KUBE_NAMESPACE) get $${i} -o jsonpath="{.spec.initContainers[*].name}"`; do \
	RES=`kubectl -n $(KUBE_NAMESPACE) logs $${i} -c $${j} 2>/dev/null`; \
	echo "initContainer: $${j}"; echo "$${RES}"; \
	echo "---------------------------------------------------";\
	done; \
	echo "Main Pod logs for $${i}"; \
	echo "---------------------------------------------------"; \
	for j in `kubectl -n $(KUBE_NAMESPACE) get $${i} -o jsonpath="{.spec.containers[*].name}"`; do \
	RES=`kubectl -n $(KUBE_NAMESPACE) logs $${i} -c $${j} 2>/dev/null`; \
	echo "Container: $${j}"; echo "$${RES}"; \
	echo "---------------------------------------------------";\
	done; \
	echo "---------------------------------------------------"; \
	echo ""; echo ""; echo ""; \
	done

redeploy: delete deploy  ## redeploy gridder

namespace: ## create the kubernetes namespace
	kubectl describe namespace $(KUBE_NAMESPACE) || kubectl create namespace $(KUBE_NAMESPACE)

delete_namespace: ## delete the kubernetes namespace
	@if [ "default" == "$(KUBE_NAMESPACE)" ] || [ "kube-system" == "$(KUBE_NAMESPACE)" ]; then \
	echo "You cannot delete Namespace: $(KUBE_NAMESPACE)"; \
	exit 1; \
	else \
	kubectl describe namespace $(KUBE_NAMESPACE) && kubectl delete namespace $(KUBE_NAMESPACE); \
	fi

deploy: namespace lint  ## deploy the helm chart
	@helm template charts/$(HELM_CHART)/ --name $(HELM_RELEASE) \
				 --namespace $(KUBE_NAMESPACE) \
         --tiller-namespace $(KUBE_NAMESPACE) \
				 --set testDataPath=$(BASEDIR)/ \
				  | kubectl -n $(KUBE_NAMESPACE) apply -f -

install: namespace  ## install the helm chart (with Tiller)
	@helm tiller run $(KUBE_NAMESPACE) -- helm install charts/$(HELM_CHART)/ --name $(HELM_RELEASE) \
				--wait \
				--namespace $(KUBE_NAMESPACE) \
				--set testDataPath=$(BASEDIR)/ \
				--tiller-namespace $(KUBE_NAMESPACE)

helm_delete: ## delete the helm chart release (with Tiller)
	@helm tiller run $(KUBE_NAMESPACE) -- helm delete $(HELM_RELEASE) --purge \
				 --set testDataPath=$(BASEDIR)/ \
				 --tiller-namespace $(KUBE_NAMESPACE)

show: ## show the helm chart
	@helm template charts/$(HELM_CHART)/ --name $(HELM_RELEASE) \
				 --namespace $(KUBE_NAMESPACE) \
				 --set testDataPath=$(BASEDIR)/ \
         --tiller-namespace $(KUBE_NAMESPACE)

lint: ## lint check the helm chart
	@helm lint charts/$(HELM_CHART)/ \
				 --namespace $(KUBE_NAMESPACE) \
				 --set testDataPath=$(BASEDIR)/ \
         --tiller-namespace $(KUBE_NAMESPACE)

delete: ## delete the helm chart release
	@helm template charts/$(HELM_CHART)/ --name $(HELM_RELEASE) \
				 --namespace $(KUBE_NAMESPACE) \
         --tiller-namespace $(KUBE_NAMESPACE) \
				 --set testDataPath=$(BASEDIR)/ \
		      | kubectl -n $(KUBE_NAMESPACE) delete -f -

describe: ## describe Pods executed from Helm chart
	@for i in `kubectl -n $(KUBE_NAMESPACE) get pods -l app.kubernetes.io/instance=$(HELM_RELEASE) -o=name`; \
	do echo "---------------------------------------------------"; \
	echo "Describe for $${i}"; \
	echo kubectl -n $(KUBE_NAMESPACE) describe $${i}; \
	echo "---------------------------------------------------"; \
	kubectl -n $(KUBE_NAMESPACE) describe $${i}; \
	echo "---------------------------------------------------"; \
	echo ""; echo ""; echo ""; \
	done

helm_dependencies: ## Utility target to install Helm dependencies
	@which helm ; rc=$$?; \
	if [ $$rc != 0 ]; then \
	curl "https://kubernetes-helm.storage.googleapis.com/helm-$(HELM_VERSION)-linux-amd64.tar.gz" | tar zx; \
	mv linux-amd64/helm /usr/bin/; \
	helm init --client-only; \
	fi
	@helm init --client-only
	@if [ ! -d $$HOME/.helm/plugins/helm-tiller ]; then \
	echo "installing tiller plugin..."; \
	helm plugin install https://github.com/rimusz/helm-tiller; \
	fi
	helm version --client
	@helm tiller stop 2>/dev/null || true

kubectl_dependencies: ## Utility target to install K8s dependencies
	@which kubectl ; rc=$$?; \
	if [ $$rc != 0 ]; then \
		sudo curl -L -o /usr/bin/kubectl "https://storage.googleapis.com/kubernetes-release/release/$(KUBECTL_VERSION)/bin/linux/amd64/kubectl"; \
		sudo chmod +x /usr/bin/kubectl; \
	fi
	@echo -e "\nkubectl client version:"
	@kubectl version --client
	@echo -e "\nkubectl config view:"
	@kubectl config view
	@echo -e "\nkubectl config get-contexts:"
	@kubectl config get-contexts
	@echo -e "\nkubectl version:"
	@kubectl version

help:  ## show this help.
	@echo "$(MAKE) targets:"
	@grep -E '^[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ": .*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
	@echo ""; echo "make vars (+defaults):"
	@grep -E '^[0-9a-zA-Z_-]+ \?=.*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = " \\?\\= | ## "}; {printf "\033[36m%-30s\033[0m %-20s %-30s\n", $$1, $$2, $$3}'
