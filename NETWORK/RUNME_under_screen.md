How to Start these:

```
screen -S prometheus-mlx5-exporter -d -m ./prometheus-mlx5-exporter.rb  -l -
screen -S ethtool-exporter -m -d ./ethtool-exporter.py -w '.x_.*' -I enp94s0f1   -p 9417
```
Later on, I will write up a systemd module...

