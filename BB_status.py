#!/usr/bin/env python3
import json
import requests

# checks status of last n builds of llvm clang-with-lto-ubuntu buildbot slave

url_Bslave="http://lab.llvm.org:8011/json/builders/clang-with-lto-ubuntu"
r = requests.get(url_Bslave)
j = r.json()
for buildNr in reversed(j['cachedBuilds'][-5:]): # last 5 buids
	url_Bbuild = "http://lab.llvm.org:8011/json/builders/clang-with-lto-ubuntu/builds/" + str(buildNr)
	r_Bbuild = requests.get(url_Bbuild)
	j_Bbuild = r_Bbuild.json()
	txt = j_Bbuild['text']
	if (txt):
		print(str(buildNr) + ": " + txt[0] + "\t" + txt[1])
	else:  # build still in progress
		print(str(buildNr) + ": in progress...")

