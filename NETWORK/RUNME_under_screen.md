How to Start these:

Needs dependencies:
````
sudu yum install ruby
sudu pip3 install prometheus_client
````


Run the following on a CLIENT which you want to gather mellanox counters for"
```
screen -S prometheus-mlx5-exporter -m -d bin/prometheus-mlx5-exporter.rb  -l -
screen -S ethtool-exporter -m -d bin/ethtool-exporter.py -w '.x_.*' -I enp94s0f1   -p 9417
```

Run these on the *opsmon* server where you can poll other clients and be polled by prometheus 
```
# sometimes it is easier to run in a docker container.. like when you don't want to pollyte your python modules
cd switch-exporter
sudo docker build .

# sometimes it is easier to python3 setup.py install    
# and then run it locally.
screen -d -m -S "switch_exporter" /usr/local/bin/switch-exporter
```

Later on, I will write up a systemd module for each of these...

How to test these:
```
curl -s server_with_switch_exporter:9117/metrics?target=10.61.10.156  
curl -s client_w_mlx5:9417/metrics
curl -s client_w_ethtool:9615/metrics
```
