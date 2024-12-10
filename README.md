# Docker TIG (Telegraf, InfluxDB, Grafana) with Huawei Telemetry Plugin

This project automates the creation of a Docker environment that compiles Telegraf with the [Telegraf Huawei Plugin](https://github.com/HuaweiDatacomm/telegraf-huawei-plugin/tree/main). By default, the plugin is configured to support Huawei Telemetry in **dial-out mode**.

The setup includes the following components:
- **Telegraf**: With the Huawei Telemetry plugin for collecting and parsing data.
- **InfluxDB**: As the time-series database to store telemetry data.
- **Grafana**: For visualizing telemetry data in real-time.

---

# Install

## Clone repositary
```bash
git clone https://github.com/ddarth/docker_TIG.git
cd docker_TIG
```

### (Optional) Disable proxy
```bash
vi Dockerfile
```
Comment this lines if no proxy required
```bash
# Proxy settings (Comment if no need)
ENV http_proxy="http://192.168.77.205:9909/"
ENV https_proxy="http://192.168.77.205:9909/"
ENV no_proxy="localhost,127.0.0.1"
```

# Run
```bash
sudo docker-compose up -d
```

## Create database for influx (replace <ENTER_YOUR_IP>)
```bash
curl -i -XPOST http://<ENTER_YOUR_IP>:8086/query --data-urlencode 'q=CREATE DATABASE influx'
```

# Debug

## Build telegraf image with huawei_telemetry plugin
```bash
sudo docker-compose build --progress plain
```

### for debugging cache can be disabled by
```bash
sudo docker-compose build --build-arg CACHE_BUST=$(date +%s) --progress plain
```

# Start
```bash
sudo docker-compose up
```

# Stop
```bash
sudo docker-compose down
```

# Restart single container
```bash
sudo docker-compose restart telegraf
```
