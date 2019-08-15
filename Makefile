PROJECT_NAME := $(notdir $(CURDIR))

ELM := npx elm

go: package-lock.json
	${ELM} reactor

index.html: src/Main.elm src/Board.elm elm.json package-lock.json
	${ELM} make --debug $<

package-lock.json: package.json
	npm install --save-dev

deploy: index.html
	git branch -D gh-pages||true
	git checkout --orphan gh-pages
	git reset
	git add -f $<
	git commit -m "deploy"
	git push --force --set-upstream origin gh-pages
	git checkout -f master
