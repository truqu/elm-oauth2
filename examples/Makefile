ELM=elm make --optimize
DIST=dist
SRC=providers
OUTPUT=../../../$(DIST)/app.min.js

.PHONY: help start

help:
	@echo -n "Usage: make <PROVIDER>/<FLOW>\n\nExamples:\n    make auth0/pkce\n    make google/authorization-code\n    make facebook/implicit"

start:
	python -m SimpleHTTPServer

%/implicit: $(DIST)
	cd $(SRC)/$@ && $(ELM) --output=$(OUTPUT) *.elm

%/authorization-code: $(DIST)
	cd $(SRC)/$@ && $(ELM) --output=$(OUTPUT) *.elm

%/pkce: $(DIST)
	cd $(SRC)/$@ && $(ELM) --output=$(OUTPUT) *.elm

$(DIST):
	mkdir -p $@
