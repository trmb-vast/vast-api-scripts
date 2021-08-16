How to Start these:

Run the following on a CLIENT which you want to gather mellanox counters for"
```
screen -S prometheus-mlx5-exporter -d -m ./prometheus-mlx5-exporter.rb  -l -
screen -S ethtool-exporter -m -d ./ethtool-exporter.py -w '.x_.*' -I enp94s0f1   -p 9417
```

Run tehse on the *opsmon* server where you can poll other clients and be polled by prometheus 
```
screen -d -m -S "switch_exporter" /usr/local/bin/switch-exporter
```

Later on, I will write up a systemd module for each of these...

How to test these:
```
curl -s server_with_switch_exporter:9117/metrics?target=10.61.10.156  
curl -s client_w_mlx5:9417/metrics
curl -s client_w_ethtool:9615/metrics
```
