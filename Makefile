PROJECT_NAME := $(notdir $(CURDIR))

ELM := npx elm

go: package-lock.json
	${ELM} reactor

index.html: src/Main.elm src/Board.elm elm.json package-lock.json
	${ELM} make --debug $<

package-lock.json: package.json
	npm install --save-dev
