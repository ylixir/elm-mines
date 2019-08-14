PROJECT_NAME := $(notdir $(CURDIR))

ELM := npx elm

go: package-lock.json
	${ELM} reactor

index.html: src/Main.elm elm.json package-lock.json
	${ELM} make

package-lock.json: package.json
	npm install --save-dev
