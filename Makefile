.PHONY: \
	force-rebuild \
	install \
	tests-locally \
	lint-locally \
	clean \
	images \
	tests \
	lint \
	lint-errors \
	tests8 \

# Project constants
IMAGE ?= convert2rhel
PYTHON ?= python3
PIP ?= pip3
VENV ?= .venv3

all: help
all2: clean images tests rpm


install: .install

.install:
	virtualenv --system-site-packages --python $(PYTHON) $(VENV); \
	. $(VENV)/bin/activate; \
	$(PIP) install --upgrade -r ./requirements/local.centos8.requirements.txt; \
	$(PIP) install -e .
	touch $@

tests-locally: install
	. $(VENV)/bin/activate; pytest

lint-locally: install
	. $(VENV)/bin/activate; ./scripts/run_lint.sh
clean:
	@rm -rf build/ dist/ *.egg-info .pytest_cache/
	@find . -name '__pycache__' -exec rm -fr {} +
	@find . -name '*.pyc' -exec rm -f {} +
	@find . -name '*.pyo' -exec rm -f {} +
	@find . -name '*~' -exec rm -f {} +
clean-rpm:
	@find ~/rpmbuild/RPMS/noarch/convert2rhel*.rpm -exec rm -f {} +
	@find ~/rpmbuild/SRPMS/convert2rhel*.rpm -exec rm -f {} +

images: .imageC7 .imageC8

.imageC7:
	@docker build -f Dockerfiles/centos7.Dockerfile -t $(IMAGE)/centos7 .
	touch $@
.imageC8:
	@docker build -f Dockerfiles/centos8.Dockerfile -t $(IMAGE)/centos8 .
	touch $@

testsall: images
	@echo 'CentOS Linux 7 tests'
	@docker run --user=$(id -ur):$(id -gr) --rm -v $(shell pwd):/data:Z $(IMAGE)/centos7 pytest
	@echo 'CentOS Linux 8 tests'
	@docker run --user=$(id -ur):$(id -gr) --rm -v $(shell pwd):/data:Z $(IMAGE)/centos8 pytest


tests: .imageC8
	@echo 'CentOS Linux 8 tests'
	@docker run --user=$(id -ur):$(id -gr) --rm -v $(shell pwd):/data:Z $(IMAGE)/centos8 pytest

lint: images
	@docker run --rm -v $(shell pwd):/data:Z $(IMAGE)/centos8 bash -c "scripts/run_lint.sh"

lint-errors: images
	@docker run --rm -v $(shell pwd):/data:Z $(IMAGE)/centos8 bash -c "scripts/run_lint.sh --errors-only"

tests8: images
	@docker run --rm -v $(shell pwd):/data:Z $(IMAGE)/centos8 pytest

rpm:
	(cd packaging && ./build_locally.sh )

# enable makefile to accept argument after command
#https://stackoverflow.com/questions/6273608/how-to-pass-argument-to-makefile-from-command-line

args = `arg="$(filter-out $@,$(MAKECMDGOALS))" && echo $${arg:-${1}}`
%:
	@:
status:
	git status
commit:
	git commit -am "$(call args, Automated commit message without details, Please read the code difference)"  && git push
pull:
	git pull
C7toC8:
	@echo "  TBC: C7toC8                 use leapp to roll CentOS 7 into Centos 8"
C8toR8:
	@echo "  TBC: C8toR8                 convert2rocky8"

help:
	@echo "Usage: make <target>"
	@echo
	@echo "Available targets are:"

	@echo "  clean                  clean the mess"
	@echo "  rpm                    create rpm locally"
	@echo "  commit {"my message"}  ie, git commit, without or with real commit message"
	@echo "  status                 ie, git status"
	@echo "  all2                   clean images tests rpm "
	@echo "  C7toC8                 use leapp to roll CentOS 7 into Centos 8"
	@echo "  C8toR8                 convert2rocky8"
	@echo ""
	@echo "Targets test, lint and test_no_lint support environment variables ACTOR and"
	@echo ""
	@echo "Possible use:"
	@echo "  MR=6 COPR_CONFIG='path/to/the/config/copr/file' make <target>"
	@echo ""

query-rpm:
	@rpm -qip  ~/rpmbuild/SRPMS/convert2rhel*.src.rpm
	@rpm -qip ~/rpmbuild/RPMS/noarch/convert2rhel*.noarch.rpm
