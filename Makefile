SHELL := /bin/bash
.ONESHELL:
.DELETE_ON_ERROR:
.SHELLFLAGS := -eu -o pipefail -c
MAKEFLAGS += --warn-undefined-variables 
MAKEFLAGS += --no-builtin-rules

ifeq ($(OS), Windows_NT)
    DETECTED_OS := Windows
endif

.PHONY: build
build: restore
	mix compile

.PHONY: docs
docs:
	mix docs

.PHONY: restore
restore:
	mix deps.get

.PHONY: test
test: restore
	mix test

.PHONY: publish
publish: build docs
	mix hex.publish
