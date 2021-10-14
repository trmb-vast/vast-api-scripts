# vast-api-scripts
![Alt Text](https://uploads.vastdata.com/2020/04/logo.svg)
Example Scripts to talk to VAST REST API

 These are primarily supported by Rob at vastdata.com

 There is a ton of end-user-preferences around which TSDB and what language to write it in.

 To make it easy to learn and springboard from, This repo is the simple combination: bash, netcat, jshon, and graphite, grafana.
 you can use it as is, or as an example to re-do in any framework, programming language, tsdb of your chosing.

 To make it simple to configure, it is run from cron once per minute,  yes, sometimes metrics are not yet ready, so there are "holes"
 in your most recent data, but VAST api returns all entries of the last 10 minutes, and graphite will
 blatantly overwrite similar data and fill in any holes.
 but yes, your grafana page lags by a minute. this is similar to other collectors.

### Where to get
git clone https://github.com/trmb-vast/vast-api-scripts.git


### Prerequisites:
* Access to a VAST cluster with admin or support credentials
* An admin host with RAM, SSD, and Docker installed
* Grafana instance (see below for quick docker setup)
* Graphite instance (or see below for a quick intro)


### Instalation and Usage
If you’ve manually compiled Graphite, then good for you. You probably then also know about go-carbon for higher performance. You should go check it out if you like graphite. 

#### Step1: If you do not already have a Graphite server, then a quick, and mostly-production ready procedure is:  Install Graphite via a docker container:  https://hub.docker.com/r/graphiteapp/graphite-statsd/


```
docker run -d\
 --name graphite\
 --restart=always\
 -p 8111:80\
 -p 2003-2004:2003-2004\
 -p 2023-2024:2023-2024\
 -p 8125:8125/udp\
 -p 8126:8126\
 -v /graphite/configs:/opt/graphite/conf\
 -v /graphite/data:/opt/graphite/storage\
 -v /graphite/statsd_config:/opt/statsd/config\
 graphiteapp/graphite-statsd
```
Note: in the example above, we remap graphite to port 8111, and we map /graphite/data on the local host to store the config and data files. 
Important: You need to create those directories/filesystems and have enough space to house the data collected.
 
 
Read up on how to change the **storage_schemas.conf**. 
set it up like shown below for high resolution for 48hrs and 1m for 120 days, and 1hour averages to to 3 years.
extend that if you like to multiple months or years but pay attention to the filesize it creates.

```
grep vast /graphite/configs/storage-schemas.conf >/dev/null 2>&1 \
  || sudo bash -c 'cat << EOF >> /graphite/configs/storage-schemas.conf
[vast]
pattern = ^vast\.
retentions = 10s:48h,1m:120d,1h:3y
EOF'

docker restart $(docker ps | grep graphiteapp | awk '{print $1}')

```
Note that graphite is listening on port 8111 for its gui, you can change that above if you like, but match it to the port number when you setup datasource in grafana


### Step2: If not already installed, Install Grafana:  https://hub.docker.com/r/grafana/grafana/       

#### Option 2a: via docker
```docker run -d --name=grafana -p 3000:3000 grafana/grafana ```
#### Option 2b: on a bare-metal machine, with /opt/opsmon base for grafana, prometheus, and snmp_exporter
``` cd opsmon ; ./setup_grafana_prometheus_opt_opsmon ```

After grafana is installed, go to http://localhost:3000  log in as admin,  change the password, and Go into gear_icon ->add datasource setting and put in the URL of the graphite instance, with localhost:8111 or whatever you might have changed it to. You sometimes can not use localhost:8111, you need real ip addr:8111.

### Step 3: Install the supporting utilities. (wget, bc, netcat, jshon)


```
[[ -x /bin/rpm ]] && yum install -y nc bc wget curl 
[[ -x /bin/apt ]] && apt-get install -y nc bc wget curl 
cd API
wget https://raw.githubusercontent.com/trmb-vast/api-tools/master/build_jshon
bash ./build_jshon
```


### Step 4:   Create Crontab entries for the VAST api collector scripts

Definition of Flags:
```
-p file with user:pass of vms user
-c clustername>
-v vms IP address
-g graphite host IP address
-r report#  -r <report#>   ... a list of reports to retreive and push into graphite
```

```
# VAST Rest API Metrics collectors. 
* * * * * /home/vastdata/opsmon/API/get-vast-topn    -p $HOME/.ssh/vms_creds -c se-201 -v 10.61.10.201 -g 10.61.201.12 > /dev/null 2>&1
* * * * * /home/vastdata/opsmon/API/get-vast-metrics -p $HOME/.ssh/vms_creds  -r 1 -r 2 -r 3 -r 4 -r 5 -r 8 -r 9 -r 15 -c se-201 -v 10.61.10.201 -g 10.61.201.12
# The following require VAST-4.0 or newer to use the new capacity and IO flow reporting API .. in example below -r /scratch1 reports on that subdir. you can change it.
#* * * * * /home/vastdata/opsmon/API/get-vast-capacity -p $HOME/.ssh/vms_creds -c -c se-202 -v 10.61.10.202 -g 10.61.201.12 -r /scratch1
#* * * * * /home/vastdata/opsmon/API/get-vast-ioflow   -p $HOME/.ssh/vms_creds -c -c se-202 -v 10.61.10.202 -g 10.61.201.12
```
Note:  You can get a **list of the Reports** (-r flag above for get-vast-metrics) with the following:
```
curl -u admin:######## -H "accept: application/json" --insecure -X GET "https://##.##.##.###/api/monitors/" | python3 -m json.tool   
```
Note:  You can get a **list of the Metrics** (and a mapping of their fqn (fully qualified name, or internal name)  to Title:

```
curl -u admin:######## -H "accept: application/json" --insecure -X GET "https://##.##.##.###/api/metrics/" | python3 -m json.tool   
```

Caution: Some of the reports are more expensive to retreive than others.. For example, report 10 and 11 are for NFS-RPC metrics.
that is not so expensive to retreive on a small cluster,  but a cluster with 32 or 64 cnodes, you probably do not want to collect 10 second interval data for each cnode. (report 12 and 13)

### Step5:  Import JSON dashboards into Grafana
 you will find a monitoring dashboard in the grafana_dashboards subdir.


### Appendix/Random examples

#### Tip:   turn on Firefox (or Chrome) web-developer debugging to discover the REST calls/syntax while you browse the VMS Gui

#### Example 1. Retreive the current alarms from a cluster.
note: check back in a week or so... This is getting added to the VAST/Grafana dashboard.
```
[vastdata@selab-cb2-c1 API]$ curl -k https://$MGMT/api/alarms/ -u admin:#### | jq
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   684  100   684    0     0   1748      0 --:--:-- --:--:-- --:--:--  1749
[
  {
    "id": 667,
    "timestamp": "2021-10-14T20:56:54.989221Z",
    "event": "https://##.##.10.202/api/events/209682/",
    "event_definition": "https://##.##.10.202/api/eventdefinitions/95/",
    "object_type": "ReplicationStream",
    "object_id": 9,
    "object_guid": "f9fe1e21-e316-4481-ab30-855b65bd81c1",
    "object_name": "protectedpath",
    "cluster": null,
    "severity": "CRITICAL",
    "alarm_message": "ProtectedPath protectedpath missed it's RPO target by 9 minutes, 20 seconds seconds",
    "metadata": {
      "internal": false,
      "property": "ReplicationMetrics,rpo_offset",
      "threshold": 124.58,
      "object_name": "protectedpath",
      "cluster_name": "selab-avnet-202"
    },
    "acknowledged": false,
    "event_type": "THRESHOLD",
    "event_name": "STREAM_CRITICAL_RPO_OFFSET"
  }
]

```

#### Example 2. Retreive specific fields from the generic cluster dashboard page:
``` 
vastdata@opsmon-20:~$ curl -s -u ${VMS_USER}:${VMS_PASS} -k https://$VMS/api/clusters/?fields=psnt,name,leader_cnode,sw_version,build,ssd_raid_state,nvram_raid_state,memory_raid_state,upgrade_state,rd_iops,rd_latency_ms,rd_bw_mb  | jq
[
  {
    "name": "selab-avnet-202",
    "rd_iops": 0,
    "rd_bw_mb": 0,
    "rd_latency_ms": 0,
    "sw_version": "4.0.0.57",
    "build": "release-4.0.0-431685",
    "leader_cnode": "cnode-16",
    "ssd_raid_state": "HEALTHY",
    "nvram_raid_state": "HEALTHY",
    "memory_raid_state": "HEALTHY",
    "upgrade_state": "DONE",
    "psnt": "selab-avnet-202"
  }
]

```


