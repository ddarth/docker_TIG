# Docker TIG + gNMIc stack (Telegraf, InfluxDB, Grafana) with Huawei Telemetry Plugin

```
┌────────┐ ┌────────┐ ┌────────┐
│ Huawei │ │ Cisco  │ │ Nokia  │
│ Device │ │ Device │ │ Device │
└──────┬─┘ └─┬──────┘ └────┬───┘
       │     │             │    
       │     │             │    
       │   Telemetry data  │    
       │     │             │    
       │     │             │    
    ┌──▼─────▼─┐      ┌────▼───┐
    │ Telegraf │      │ gNMIc  │
    └─────────┬┘      └┬───────┘
              │        │        
             ┌▼────────▼┐       
             │ InfluxDB │       
             └─────┬────┘       
                   │            
                   │            
             ┌─────▼────┐       
             │ Grafana  │       
             └──────────┘       
```

This project simplifies the setup of a telemetry monitoring stack using Docker. It allows network engineers to easily collect, store, and visualize telemetry data from Huawei, Nokia, and Cisco devices. By default, the Huawei Telemetry Plugin is configured to support **dial-out mode** telemetry.

The setup includes the following components:
- **Telegraf**: With the Huawei Telemetry plugin for collecting and parsing data.
- **InfluxDB**: As the time-series database to store telemetry data.
- **Grafana**: For visualizing telemetry data in real-time.
- **gNMIc**: For collecting data from Nokia devices in dial-out mode.

---

# Table of Contents
1. [Installation](#installation)
2. [Running the Stack](#running-the-stack)
3. [Configuration on Network Devices](#configuration-on-network-devices)
    - [Huawei](#huawei)
    - [Nokia](#nokia)
    - [Cisco](#cisco)
4. [Debugging](#debugging)
5. [Additional Notes](#additional-notes)

---

# Installation

## Clone the Repository

```bash
# Clone the repository to your local machine
git clone https://github.com/ddarth/docker_TIG.git
cd docker_TIG
```

## Security Configuration (REQUIRED)

Before first run, you need to configure environment variables:

1. Create .env file from template:
   ```bash
   cp .env.example .env
   ```

2. Edit .env and set secure passwords:
   ```bash
   nano .env
   # Change INFLUXDB_ADMIN_PASSWORD and GF_SECURITY_ADMIN_PASSWORD
   ```

3. Set restrictive permissions:
   ```bash
   chmod 600 .env
   ```

4. **(Optional)** If proxy is NOT needed, comment out HTTP_PROXY lines in .env:
   ```bash
   nano .env
   # Comment out:
   #HTTP_PROXY=http://192.168.11.205:9909/
   #HTTPS_PROXY=http://192.168.11.205:9909/
   ```

**Important:** .env file contains passwords and should NOT be committed to Git!

# Running the Stack

After creating .env file, start the stack:

## Start the Stack

```bash
sudo docker-compose up -d
```

**Note:** To rebuild with new proxy settings:
```bash
sudo docker-compose build --no-cache
sudo docker-compose up -d
```

## Create the Database for InfluxDB

Replace `<ENTER_YOUR_HOST_IP>` with the IP address of your host:
```bash
curl -i -XPOST http://<ENTER_YOUR_HOST_IP>:8086/query --data-urlencode 'q=CREATE DATABASE influx'
```

## (Optional) Remove Unused Images

After the build process, you can clean up unused Docker images:
```bash
sudo docker system prune -a
```
> **Warning**: Be careful! This command removes all unused Docker images.

---

# Configuration on Network Devices

## Huawei

### Configure TWAMP-Light Client and Sender

Example:
```plaintext
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

### Configure TWAMP-Light Reflector

```plaintext
nqa twamp-light
 responder
  test-session 100 local-ip 192.168.0.169 remote-ip 192.168.0.168 local-port 64694 remote-port 64694 description Link-1
  test-session 101 local-ip 192.168.0.171 remote-ip 192.168.0.170 local-port 64694 remote-port 64694 description Link-1
#
```

### Configure Telemetry in Dial-Out Mode

```plaintext
telemetry
 #
 sensor-group twampSensors
  # Interface example
  sensor-path huawei-ifm:ifm/interfaces/interface[name="GigabitEthernet0/2/0"]/mib-statistics
  # TWAMP-Light example
  sensor-path huawei-twamp-controller:twamp-controller/client/sessions/session/huawei-twamp-statistics:statistics
 #
 destination-group gNMI1
  ipv4-address 192.168.10.1 port 57400 protocol grpc no-tls
 #
 subscription subscription1
  # Set your source interface if needed
  # local-source-interface LoopBack0
  encoding json
  sensor-group twampSensors sample-interval 5000
  destination-group gNMI1
#
```
> **Note**: Tested on V800R022 software on ATN910 and NE8000.

## Nokia

### Configure TWAMP-Light Client and Sender

Example:
```plaintext
/configure oam-pm
        session "My_session_name" test-family ip session-type proactive create
            meas-interval 1-min create
            exit
            ip
                dest-udp-port 64373
                destination 192.168.0.187
                router-instance "Base"
                source 192.168.0.186
                source-udp-port 64383
                twamp-light test-id 2002 create
                    pad-size 1454
                    record-stats delay-and-loss
                    no shutdown
                exit
            exit
        exit
```

### Configure Telemetry in Dial-Out Mode

```plaintext
/configure system telemetry
            destination-group "gNMI1" create
                allow-unsecure-connection
                tcp-keepalive
                    no shutdown
                exit
                destination 192.168.10.1 port 57401 create
                    router-instance "Base"
                exit
            exit
            sensor-groups
                sensor-group "twamp-stats" create
                    # TWAMP-Light example
                    path "/state/oam-pm/session/ip/twamp-light/statistics/loss/measurement-interval[duration=raw]" create
                    exit
                    # Interface example
                    path "/state/port[port-id=1/1/31]/ethernet/statistics/out-octets" create
                    exit
                    path "/state/port[port-id=1/1/32]/ethernet/statistics/out-octets" create
                    exit
                exit
            exit
            persistent-subscriptions
                subscription "subscription1" create
                    destination-group "gNMI1"
                    mode sample
                    sensor-group "twamp-stats"
                    local-source-address 192.168.1.16
                    no shutdown
                exit
            exit
```
> **Note**: Tested on 23.10 IXR-e, 7750.

> **Warning**: Telemetry collector port for Nokia devices is different than Huawei because gNMIc is used.

## Cisco
Cisco devices have not been tested. To configure Cisco devices, use the [Cisco Model-Driven Telemetry (MDT) Input Plugin](https://github.com/influxdata/telegraf/blob/master/plugins/inputs/cisco_telemetry_mdt/README.md).

---

# Debugging

## Build Telegraf Image with Huawei Telemetry Plugin

```bash
sudo docker-compose build --progress plain
```

### Disable Docker Cache for Debugging

```bash
sudo docker-compose build --build-arg CACHE_BUST=$(date +%s) --progress plain
```

## Manage the Stack

### Start the Stack

```bash
sudo docker-compose up
```

### Stop the Stack

```bash
sudo docker-compose down
```

### Restart a Single Container

```bash
sudo docker-compose restart telegraf
```

---

# Additional Notes

- Ensure your Docker and `docker-compose` versions are up to date.
- Test the setup incrementally, verifying each device configuration and data flow in the stack.

