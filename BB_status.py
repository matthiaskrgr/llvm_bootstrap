#!/usr/bin/env python3
import json
import requests
import datetime  # unix to HR time

# checks status of last n builds of llvm clang-with-lto-ubuntu buildbot slave

url_Bslave="http://lab.llvm.org:8011/json/builders/clang-with-lto-ubuntu"
r = requests.get(url_Bslave)
j = r.json()
for buildNr in reversed(j['cachedBuilds'][-5:]): # last 5 buids
	url_Bbuild = "http://lab.llvm.org:8011/json/builders/clang-with-lto-ubuntu/builds/" + str(buildNr)
	r_Bbuild = requests.get(url_Bbuild)
	j_Bbuild = r_Bbuild.json()
	txt = j_Bbuild['text']
	# handle times
	times = j_Bbuild['times']
	# [starttime,endtime], for running jobs [starttime, "None"]
	start_time = datetime.datetime.fromtimestamp(float(times[0])).strftime('%H:%M:%S')
	if str(times[1]) == "None":
		end_time = "now"
	else:
		end_time = datetime.datetime.fromtimestamp(float(times[1])).strftime('%H:%M:%S')

	if (txt):
		print(str(buildNr) + ": " + txt[0] + "\t" + txt[1] + " " + start_time + " - " + end_time)
	else:  # build still in progress
		print(str(buildNr) + " " + start_time + " - " + end_time)
