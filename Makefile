#
# Check that given variable is set and has non-empty value,
# die with an error otherwise.
#
# Params:
#   1. Variable name to test
check_defined = \
    $(if $(value $1),, \
      $(error $1 is undefined))

# set current working directory
pwd=$(shell pwd)


##############################
# commands outside container #
##############################
TKUSER ?= eai.lee
DEFAULT_IMAGE_NAME=dice
# PROJECT_DIR_ON_HOST should always hold the project directory on the *docker host*.
# Depending on the specific context/target, the docker host may be *your laptop* (e.g. `make run` context), or a borgy
# node (e.g. `make jupyter.borgy` context)
PROJECT_DIR_ON_HOST ?= $(pwd)
PROJECT_DIR_IN_CONTAINER ?= /src/app/
DEFAULT_VOLUME = -v $(PROJECT_DIR_ON_HOST):$(PROJECT_DIR_IN_CONTAINER)
DEFAULT_INTERACTIVE = -ti
DEFAULT_BUILD_STAGE = jupyterlab
vol ?= $(DEFAULT_VOLUME)
interactive ?=$(DEFAULT_INTERACTIVE)
registry ?= registry.console.elementai.com
build_stage ?= $(DEFAULT_BUILD_STAGE)
image_name ?= $(registry)/$(TKUSER)/$(DEFAULT_IMAGE_NAME)
version ?= latest
LOCAL_IMAGE_FULL_NAME = $(image_name):$(version)
survey_data ?= $(TKUSER).adult:/workspace 
dice_src ?= $(TKUSER).dice:/dice

############################
# Docker related variables #
############################
DOCKER=@docker
DOCKER_BUILD_ARGS = --progress plain

# We use docker buildkit, so enable it
export DOCKER_BUILDKIT=1

#
# Params:
#   1. docker image full name (in the ‘name:tag’ format)
#   2. path/context (typically ".")
#   3. extra arguments
define _build
	$(DOCKER) build $(DOCKER_BUILD_ARGS) -t $(1) $(2)
endef

# build docker image
build:
	@$(call _build, $(LOCAL_IMAGE_FULL_NAME), .)

# set up toolkit build args
define _pre_push_setup
	@$(eval toolkit_docker_registry=$(shell eai docker get-registry))
	@$(eval toolkit_account_id=eai.lee)
	@$(eval toolkit_image_full_name=\
	    $(toolkit_docker_registry)/$(toolkit_account_id)/$(DEFAULT_IMAGE_NAME):$(version))
endef

# build and push docker image to toolkit registry
push.toolkit: build
	@echo "Local image built as $(LOCAL_IMAGE_FULL_NAME)"
	@$(call _pre_push_setup)
	$(DOCKER) tag $(LOCAL_IMAGE_FULL_NAME) $(toolkit_image_full_name)
	@echo "Local image tagged as $(toolkit_image_full_name)"
	$(DOCKER) push $(toolkit_image_full_name)
	@echo "Image pushed to toolkit registry as $(toolkit_image_full_name)"

#######################
# spin up jupyter lab #
#######################

jupyter_host_port ?= 8080
TOOLKIT_EXPERIMENTS_OPTIONS ?= --cpu 1 --mem 64 --account eai.lee --gpu 1 --gpu-mem 8

.PHONY: jupyter
jupyter:
	@$(call _pre_push_setup)
	eai job submit \
		$(TOOLKIT_EXPERIMENTS_OPTIONS) \
		--image $(toolkit_image_full_name) \
		--data $(survey_data) \
		--data $(dice_src):rw \
		-- jupyter lab --ip=0.0.0.0 --port=$(jupyter_host_port) --no-browser \
    	--LabApp.token='' \
    	--LabApp.custom_display_url=https://${EAI_JOB_ID}.job.console.elementai.com \
    	--LabApp.allow_remote_access=True \
    	--LabApp.allow_origin='*' \
    	--LabApp.disable_check_xsrf=True