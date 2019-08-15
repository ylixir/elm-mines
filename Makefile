PROJECT_NAME := $(notdir $(CURDIR))

ELM := npx elm

go: package-lock.json
	${ELM} reactor

index.html: src/Main.elm src/Board.elm elm.json package-lock.json
	${ELM} make --debug $<

package-lock.json: package.json
	npm install --save-dev

deploy: index.html
	git checkout gh-pages
	git add $<
	git commit -m "deploy"
	git push
	git checkout master
