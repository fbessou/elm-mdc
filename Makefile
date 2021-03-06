ELM=elm-make --yes --warn
PAGES=../elm-mdc-gh-pages

all: build-demo

build-demo: elm-global-events.js elm-focus-trap.js material-components-web.css
	mkdir -p build
	rsync -r demo/images build
	cp demo/page.html build/index.html
	cp material-components-web.css build/
	cp elm-global-events.js build/
	cp elm-mdc.js build/
	cp elm-focus-trap.js build/
	(cd demo; $(ELM) Demo.elm --output ../build/demo.js)

setup:
	npm i

elm-global-events.js: elm-global-events/elm-global-events.js
	cp elm-global-events/elm-global-events.js .

elm-focus-trap.js:
	(cd elm-focus-trap; make)
	cp elm-focus-trap/bundle.js elm-focus-trap.js

material-components-web.css:
	cp node_modules/material-components-web/dist/material-components-web.css .

docs:
	$(ELM) --docs=documentation.json

pages: build-demo
	rsync -r build/ $(PAGES)
	(cd $(PAGES); git commit -am "Update."; git push origin gh-pages)

cleanish:
	rm -rf build

clean:
	rm -rf build
	rm -rf elm-stuff/build-artifacts demo/elm-stuff/build-artifacts

distclean:
	rm -rf build
	rm -rf elm-stuff demo/elm-stuff
