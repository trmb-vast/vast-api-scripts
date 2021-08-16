# Prometheus mlx5 Exporter

Basic Prometheus exporter for Mellanox mlx5 sysfs Infiniband counters.

# Usage

```
Usage: prometheus-mlx5-exporter.rb [OPTIONS]

Export Mellanox mlx5 sysfs Infiniband counters to Prometheus.
Logging to stdout will force running in foreground, even with --daemonize.

Options:
    -b, --bind=IP                    Local IP address to bind to [0.0.0.0]
    -d, --[no-]daemonize             Run as daemon [false]
    -l, --logfile=FILENAME           File to log to ('-' for stdout) [none]
    -p, --port=PORT                  Port to listen on [9615]
    -i, --include=REGEXP             Inclusion regexp [all]
    -x, --exclude=REGEXP             Exclusion regexp [none]
    -h, --help                       Show this message
```
