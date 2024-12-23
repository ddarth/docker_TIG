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
ENV http_proxy="http://192.168.11.205:9909/"
ENV https_proxy="http://192.168.11.205:9909/"
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

# (Optional) Remove unused imagas after build process
```bash
sudo docker system prune -a
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

# Configuration on network devices
## Huawei
Configure twamp-light client and sender
For example:
```
#
nqa twamp-light
 client
  test-session 101 sender-ip 192.168.0.168 reflector-ip 192.168.0.169 sender-port 64694 reflector-port 64694 padding 1454 description Link_1
  test-session 102 sender-ip 192.168.0.170 reflector-ip 192.168.0.171 sender-port 64694 reflector-port 64694 padding 1454 description Link_2
 sender
  test start-continual test-session 101
  test start-continual test-session 102
#
```
Configure telemetry in dial-out mode
```
telemetry
 #
 sensor-group twampSensors
# Interface example
#  sensor-path huawei-ifm:ifm/interfaces/interface[name="GigabitEthernet0/2/0"]/mib-statistics
  sensor-path huawei-twamp-controller:twamp-controller/client/sessions/session/huawei-twamp-statistics:statistics
 #
 destination-group gNMI1
  ipv4-address 192.168.10.1 port 57400 protocol grpc no-tls
 #
 subscription subscription1
# Set your source interface if need
#  local-source-interface LoopBack0
  encoding json
  sensor-group twampSensors sample-interval 5000
  destination-group gNMI1
#
```
