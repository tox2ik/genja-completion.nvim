# Refresh the shipped word list from the URL in lua/genja/completion/dictionary.lua.
DICT_URL := $(shell sed \
	-n "s/^local URL = '\(.*\)'.*/\1/p" \
	lua/genja/completion/dictionary.lua)

update-dict:
	curl -fsSL -o dict/en.txt.tmp $(DICT_URL)
	mv dict/en.txt.tmp dict/en.txt

.PHONY: update-dict
