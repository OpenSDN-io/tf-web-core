#
# Copyright (c) 2014 Juniper Networks, Inc. All rights reserved.
#

REPORTER = dot
WEBUISERVER = contrail-web-core
WEBUICLIENT = contrail-web-controller
WEBUITHIRDPARTY = contrail-webui-third-party
THIRD_PARTY='../contrail-webui-third-party'
WEBCONTROLLERREPO = ../contrail-web-controller,webController
GENERATEDS = src/contrail-api-client/generateds
CONTROLLER = controller
BRANCH = master

define fetch_xsd_schemas
	 wget -qO - https://github.com/opensdn-io/tf-api-client/tree/${BRANCH}/schema | \
	 awk -F '[<>]' '/.*\.xsd/ { for(i=0;i<=NF;i++) { if($$i ~ /[^<>].*\.xsd$$/) { print $$i; break; } } }' | \
	 while read -r line; do wget https://raw.githubusercontent.com/opensdn-io/tf-api-client/$(BRANCH)/schema/$$line; done;
endef

$(WEBUISERVER):
	if [ ! -d ../$(WEBUISERVER) ]; then git clone git@github.com:opensdn-io/tf-web-core.git ../$(WEBUISERVER); else cd ../$(WEBUISERVER) && touch testFile && git stash; git pull --rebase; git stash pop; rm testFile; fi

$(WEBUICLIENT):
	if [ ! -d ../$(WEBUICLIENT) ]; then git clone git@github.com:opensdn-io/tf-web-controller.git ../$(WEBUICLIENT); else cd ../$(WEBUICLIENT) && touch testFile && git stash; git pull --rebase; git stash pop; rm testFile; fi

$(WEBUITHIRDPARTY):
	if [ ! -d ../$(WEBUITHIRDPARTY) ]; then git clone git@github.com:opensdn-io/tf-webui-third-party.git ../$(WEBUITHIRDPARTY); else cd ../$(WEBUITHIRDPARTY) && touch testFile && git stash; git pull --rebase; git stash pop; rm testFile; fi

$(GENERATEDS):
	if [ ! -d ../$(GENERATEDS) ]; then git clone https://github.com/Juniper/contrail-generateDS.git ../$(GENERATEDS); else cd ../$(GENERATEDS) && touch testFile && git stash; git pull --rebase; git stash pop; rm testFile; fi

$(CONTROLLER):
	rm -rf ../src/contrail-api-client/schema/;
	mkdir -p ../src/contrail-api-client/schema/;
	cd ../src/contrail-api-client/schema/ && $(call fetch_xsd_schemas)


repos: $(WEBUISERVER) $(WEBUICLIENT) $(WEBUITHIRDPARTY) $(GENERATEDS) $(CONTROLLER)

fetch-schemas: $(GENERATEDS) $(CONTROLLER)

fetch-pkgs-prod:
	python3 ../contrail-webui-third-party/fetch_packages.py -f ../contrail-webui-third-party/packages.xml
	npm install -g sass
	make clean
	rm -rf node_modules
	mkdir -p node_modules
	cp -rf $(THIRD_PARTY)/node_modules/* node_modules/.

fetch-pkgs-dev:
	make clean
	rm -rf node_modules
	mkdir -p node_modules
	python3 ../contrail-webui-third-party/fetch_packages.py -f ../contrail-webui-third-party/packages.xml
	python3 ../contrail-webui-third-party/fetch_packages.py -f ../contrail-webui-third-party/packages_dev.xml
	cp -rf $(THIRD_PARTY)/node_modules/* node_modules/.

package:
	make clean
	make fetch-pkgs-prod 
	rm -f webroot/html/dashboard.html
	rm -f webroot/html/login.html
	rm -f webroot/html/login-error.html
	cp -a webroot/html/dashboard.tmpl webroot/html/dashboard.html
	cp -a webroot/html/login.tmpl webroot/html/login.html
	cp -a webroot/html/login-error.tmpl webroot/html/login-error.html
	./generate-files.sh 'prod-env' $(REPO)
	./dev-install.sh
	rm -f built_version
	# build the minified, unified files.
	./build-files.sh "prod-env" $(REPO)
	./prod-dev.sh webroot/html/dashboard.html prod_env dev_env true
	./prod-dev.sh webroot/html/login.html prod_env dev_env true
	./prod-dev.sh webroot/html/login-error.html prod_env dev_env true

make-ln:
	cp -af webroot/html/dashboard.html webroot/html/dashboard.tmpl
	rm -f webroot/html/dashboard.html
	ln -sf ../../webroot/html/dashboard.tmpl webroot/html/dashboard.html
	cp -af webroot/html/login.html webroot/html/login.tmpl
	rm -f webroot/html/login.html
	ln -sf ../../webroot/html/login.tmpl webroot/html/login.html
	cp -af webroot/html/login-error.html webroot/html/login-error.tmpl
	rm -f webroot/html/login-error.html
	ln -sf ../../webroot/html/login-error.tmpl webroot/html/login-error.html
	rm -f webroot/html/login-error.html
	ln -sf ../../webroot/html/login-error.tmpl webroot/html/login-error.html
	
dev-env:
	mkdir -p webroot/html
	ln -sf ../../webroot/html/dashboard.tmpl webroot/html/dashboard.html
	ln -sf ../../webroot/html/login.tmpl webroot/html/login.html
	ln -sf ../../webroot/html/login-error.tmpl webroot/html/login-error.html
	if [ ! -d ../$(CONTROLLER) ]; then make fetch-schemas; fi
	bash generate-keys.sh
	./generate-files.sh "dev-env" $(REPO)
	./dev-install.sh
	rm -f built_version
	./prod-dev.sh webroot/html/dashboard.html dev_env prod_env true
	./prod-dev.sh webroot/html/login.html dev_env prod_env true
	./prod-dev.sh webroot/html/login-error.html dev_env prod_env true
	make make-ln
	# For test files, we will setting the env file with current environment.
	./unit-test.sh set-env "dev"

ui-schemas:
	node webroot/js/common/transformer.js

prod-env:
	mkdir -p webroot/html
	ln -sf ../../webroot/html/dashboard.tmpl webroot/html/dashboard.html
	ln -sf ../../webroot/html/login.tmpl webroot/html/login.html
	ln -sf ../../webroot/html/login-error.tmpl webroot/html/login-error.html
	./generate-files.sh "dev-env" $(REPO)
	./dev-install.sh
	rm -f built_version
	# build the minified, unified files.
	./build-files.sh "prod-env" $(REPO)
	./prod-dev.sh webroot/html/dashboard.html prod_env dev_env true
	./prod-dev.sh webroot/html/login.html prod_env dev_env true
	./prod-dev.sh webroot/html/login-error.html prod_env dev_env true
	make make-ln
	# For test files, we will setting the env file with current environment.
	./unit-test.sh set-env "prod"

chrome-extension:
ifndef REPO
	./generate-files.sh 'prod-env' $(WEBCONTROLLERREPO)
else
	./generate-files.sh 'prod-env' $(REPO)
endif
	./dev-install.sh
	./chrome-extension.sh

clear-cache-dev:
	rm -f built_version
	./prod-dev.sh webroot/html/dashboard.html dev_env prod_env false
	./prod-dev.sh webroot/html/login.html dev_env prod_env false
	./prod-dev.sh webroot/html/login-error.html dev_env prod_env false
	make make-ln

clear-cache-prod:
	rm -f built_version
	./prod-dev.sh webroot/html/dashboard.html prod_env dev_env false
	./prod-dev.sh webroot/html/login.html prod_env dev_env false
	./prod-dev.sh webroot/html/login-error.html prod_env dev_env false
	make make-ln

css-lint:
	./linting.sh $(REPO)

test-env:
	./unit-test.sh init $(REPO)

test-ui:
	./unit-test.sh ui $(REPO) $(ENV)

test-core:
	./unit-test.sh core $(REPO) $(ENV)

test: test-env test-core test-ui

clean:
	rm -rf node_modules
	rm -rf webroot/assets

.PHONY: package dev-env prod-env test clean

