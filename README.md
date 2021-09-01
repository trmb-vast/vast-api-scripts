# vast-api-scripts
Scripts to talk to VAST REST API

 These are informally supported by Rob@vastdata.com
 There is a ton of end-user-preferences around which TSDB and what language to write it in

 This repo is the more simple combination: bash, netcat, jshon, and graphite, grafana.
 you can use it as is, or as an example to re-do in any framework,language,tsdb of your chosing.

 yes, it is once per minute,  yes, sometimes metrics are not yet ready, so there are "holes"
 in your most recent data, but VAST api returns all of the last 10 minutes, and graphite will
 blatantly overwrite similar data and fill in any holes.
 and yes, your grafana page lags by a minute.

### Wheretoget
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
Note: in the example above, we map /graphite/data on the local host to store the conf files. You need to create those directories/filesystems and have enough space to house the data collected.
 
 
Read up on how to change the **storage_schemas.conf**. 
set it up like shown below for high resolution for 24hrs and 1m for 90 days.

```
grep vast /graphite/configs/storage-schemas.conf >/dev/null 2>&1 \
  || sudo bash -c 'cat << EOF >> /graphite/configs/storage-schemas.conf
[vast]
pattern = ^vast\.
retentions = 10s:24h,1m:90d
EOF'

docker restart $(docker ps | grep graphiteapp | awk '{print $1}')

```
Note that graphite is listening on port 8111 for its gui, you can change that above if you like, but match it to the port number when you setup datasource in grafana


### Step2: If not already installed, Install Grafana:  https://hub.docker.com/r/grafana/grafana/       

#### Option 2a: via docker
```docker run -d --name=grafana -p 3000:3000 grafana/grafana ```
#### Option 2b: on a bare-metal machine, with /opt/opsmon base for grafana, prometheus, and snmp_exporter
``` cd opsmon ; ./setup_grafana_prometheus_opt_opsmon ```

After grafana is installed, go to http://localhost:3000  log in as admin,  and Go into gear_icon ->add datasource setting and put in the URL of the graphite instance, with localhost:8111 or whatever you might have changed it to. You sometimes can not use localhost:8111, you need real ip addr.

### Step 3: Install the supporting utilities. (jshon)


```
apt-get install -y nc wget curl 
cd API
wget https://raw.githubusercontent.com/trmb-vast/api-tools/master/build_jshon
bash ./build_jshon
```

### Step 4:   Create Crontab entries

Definition of Flags:
```
-p file with user:pass of vms user
-c clustername>
-v vms IP address
-g graphite host IP address
-r report#  -r <report#>   ... a list of reports to retreive and push into graphite
```

```
* * * * * /home/vastdata/opsmon/API/get-vast-topn  -p $HOME/.ssh/vms_creds -c se-201 -v 10.61.10.201 -g 10.61.201.12 > /dev/null 2>&1
#
* * * * * /home/vastdata/opsmon/API/get-vast-metrics -p $HOME/.ssh/vms_creds  -r 1 -r 2 -r 3 -r 4 -r 5 -r 8 -r 9 -r 15 -c se-201 -v 10.61.10.201 -g 10.61.201.12
```


### Step5:  Import JSON dashboards into Grafana
 you will find a monitoring dashboard in the grafana_dashboards subdir.

