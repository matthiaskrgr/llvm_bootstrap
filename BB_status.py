#!/usr/bin/env python3
import json
import requests

# checks status of last 3 builds of llvm clang-with-lto-ubuntu buildbot slave

url_Bslave="http://lab.llvm.org:8011/json/builders/clang-with-lto-ubuntu"
r = requests.get(url_Bslave)
j = r.json()
for buildNr in reversed(j['cachedBuilds'][-3:]): # last 3 buids
	url_Bbuild = "http://lab.llvm.org:8011/json/builders/clang-with-lto-ubuntu/builds/" + str(buildNr)
	r_Bbuild = requests.get(url_Bbuild)
	j_Bbuild = r_Bbuild.json()
	print(str(buildNr) + ": " + j_Bbuild['text'][0] + "\t" + j_Bbuild['text'][1])
