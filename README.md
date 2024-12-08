# First run

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
