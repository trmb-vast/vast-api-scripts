# vast-api-scripts
Scripts to talk to VAST REST API

 These are informally supported by Rob@vastdata.com
 There is a ton of end-user-preferences around which TSDB and what language to write it in.

 This repo is the more simple combination: bash, netcat, jshon, and graphite.
 you can use it as is, or as an example to re-do in any framework of your chosing.

 yes, it is once per minute,  yes, sometimes metrics are not yet ready, so there are "holes"
 in your most recent data, but VAST api returns all of the last 10 minutes, and graphite will
 blatantly overwrite similar data and fill in any holes.
 so yes, your grafana page lags by a minute.

