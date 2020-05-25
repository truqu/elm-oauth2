ELM=elm make --optimize
DIST=dist
SRC=providers
OUTPUT=../../../$(DIST)/app.min.js

.PHONY: help start

help:
	@echo -n "Usage: make <PROVIDER>/<FLOW>"
	@echo -n "\n\nAvailable targets:\n"
	$(eval DIRS := $(shell find providers -maxdepth 2 -mindepth 2 -type d))
	@echo -n $(foreach EL,$(DIRS),$(shell echo "$(EL)" | cut -c 11-)) | tr " " "\n" | sed "s/^/    /"
	@echo -n "\n\nExamples:\n    make facebook/implicit\n    make auth0/pkce"

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
