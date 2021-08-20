# Whats what
VAST_Cluster_Performance-20200921.json  --  a dashboard which sources from graphite, and displays bw, latency, iops, space, and top N

this directory is frequently updated.  check back frequently yourself!
I now use a dashboard importer/exporter which i found in github/gist.. (credits later)

and a datasource importer script which works, but does not save and test, thus a follow-on dashboard import does not have datasource=prometheus.

so you have to do this:

* ../opsmon/setup_opt_grafana_prometheus   
* open up grafana,  put in the admin password, change it back to admin
* then add a datasource (prometheus) via the gui
* then bash  ./import_dashboards_apikey  -u admin -w admin -p admin-localhost-3000 -t localhost:3000
