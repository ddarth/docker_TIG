# Используем официальный образ Telegraf в качестве основы
FROM telegraf:latest
#FROM golang:1.23


ENV http_proxy="http://192.168.77.205:9909/"
ENV https_proxy="http://192.168.77.205:9909/"
ENV no_proxy="localhost,127.0.0.1"
#ENV http_proxy="socks5h://localhost:9908"
#ENV https_proxy="socks5h://localhost:9908"

# Устанавливаем необходимые зависимости
RUN apt-get \
#-o Acquire::http::proxy="socks5h://localhost:9908" \
#-o Acquire::https::proxy="socks5h://localhost:9908" \
update && apt-get \
#-o Acquire::http::proxy="socks5h://localhost:9908" \
#-o Acquire::https::proxy="socks5h://localhost:9908" \
install -y \
    curl \
    unzip \
    make \
    git \
    gcc \
    g++ \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Устанавливаем Go (пакет Go должен быть доступен по указанному пути)
RUN curl -O https://dl.google.com/go/go1.17.1.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.17.1.linux-amd64.tar.gz && \
    rm go1.17.1.linux-amd64.tar.gz

# Устанавливаем протоколы для gRPC
RUN curl -L -o protoc-3.11.4-linux-x86_64.zip https://github.com/protocolbuffers/protobuf/releases/download/v3.11.4/protoc-3.11.4-linux-x86_64.zip && \
    unzip protoc-3.11.4-linux-x86_64.zip -d /usr/local && \
    rm protoc-3.11.4-linux-x86_64.zip

# Устанавливаем переменные окружения для Go
ENV GOROOT=/usr/local/go
ENV GOPATH=/usr/local/goWorkplace
ENV PATH=$PATH:$GOROOT/bin:$GOPATH/bin

# Проверка версии Go (для отладки)
RUN go version

# Устанавливаем gRPC-плагин для Go
#RUN go get -u github.com/golang/protobuf/protoc-gen-go
RUN go install github.com/golang/protobuf/protoc-gen-go@v1.5.0

# Клонируем репозиторий Telegraf Huawei Plugin
RUN git clone --branch release-1.20 https://github.com/influxdata/telegraf.git /opt/telegraf

# Клонируем репозиторий Telegraf Huawei Plugin
RUN git clone https://github.com/HuaweiDatacomm/telegraf-huawei-plugin.git /opt/telegraf-huawei-plugin


# Устанавливаем необходимые скрипты и зависимости для Telegraf Huawei Plugin
WORKDIR /opt/telegraf-huawei-plugin
ENV TELEGRAFROOT=/opt/telegraf
RUN chmod +x install.sh && ./install.sh

# Патчим proto файл
#RUN sed -i '/^package \S*;/a option go_package="/";' test.proto

# Копируем proto файлы Huawei
RUN git clone https://github.com/HuaweiDatacomm/proto.git /opt/proto

# Патчим файл huawei-debug.proto
#RUN cp /opt/proto/network-router/8.22.0/huawei-debug.proto /opt/telegraf/plugins/parsers/huawei_grpc_gpb/telemetry_proto && \
#    cd /opt/telegraf/plugins/parsers/huawei_grpc_gpb/telemetry_proto && \
#    sed -i '/^package \S*;/a option go_package="/huawei_debug";' huawei-debug.proto && \
#    protoc --go_out=plugins=grpc:. huawei-debug.proto && \
#    cat huawei-debug.proto

# Список файлов (без расширений .proto), который вы хотите скопировать и обработать
ARG PROTO_FILES="huawei-debug huawei-ifm huawei-twamp-controller"  # Указывайте файлы без расширения .proto

ARG CACHE_BUST

RUN for file in $PROTO_FILES; do \
        # Копируем файлы .proto в нужную директорию
        cp /opt/proto/network-router/8.22.0/$file.proto /opt/telegraf/plugins/parsers/huawei_grpc_gpb/telemetry_proto && \
        cd /opt/telegraf/plugins/parsers/huawei_grpc_gpb/telemetry_proto && \
        # Подставляем имя файла (без расширения) в команду sed
        sed -i "/^package \S*;/a option go_package=\"/$file\";" $file.proto && \
        # Генерируем Go-код с помощью protoc
        protoc --go_out=plugins=grpc:. $file.proto && \
        # Выводим содержимое файла
        echo "Added:" && \
        cat $file.proto | grep go_package &&\
        echo "  to file $file.proto" ; \
    done

RUN ls -l /opt/telegraf/plugins/parsers/huawei_grpc_gpb/telemetry_proto

# Хак для отключения кэширования (передается через агрумент при build)
ARG CACHE_BUST

RUN ls -l /opt/telegraf/plugins/parsers/
RUN ls -l /opt/telegraf/plugins/parsers/huawei_grpc_gpb/
RUN ls -l
RUN ls -l /opt/telegraf/plugins/parsers/huawei_grpc_gpb/telemetry_proto
RUN cat /opt/telegraf/plugins/parsers/huawei_grpc_gpb/telemetry_proto/HuaweiTelemetry.go
RUN cat /opt/telegraf/plugins/parsers/huawei_grpc_gpb/telemetry_proto/huawei-debug.proto

# Делаем необходимые изменения в коде (например, в HuaweiTelemetry.go)
#RUN sed -i 's#//"github.com/influxdata/telegraf/plugins/parsers/huawei_grpc_gpb/telemetry_proto/huawei_debug"#"github.com/influxdata/telegraf/plugins/parsers/huawei_grpc_gpb/telemetry_proto/huawei_debug"#' /opt/telegraf/plugins/parsers/huawei_grpc_gpb/telemetry_proto/HuaweiTelemetry.go
#RUN sed -i 's#//PathKey#PathKey#g' /opt/telegraf/plugins/parsers/huawei_grpc_gpb/telemetry_proto/HuaweiTelemetry.go


RUN ImportPaths="// Patched by docker"; \
    for file in $PROTO_FILES; do \
        # Формируем строки с нужным форматом для каждого файла
        ImportPaths="$ImportPaths\n\"github.com/influxdata/telegraf/plugins/parsers/huawei_grpc_gpb/telemetry_proto/$file\"" ; \
    done && \
    echo "$ImportPaths" && \
    sed -i "s#//\"github.com/influxdata/telegraf/plugins/parsers/huawei_grpc_gpb/telemetry_proto/huawei_debug\"#$ImportPaths#" /opt/telegraf/plugins/parsers/huawei_grpc_gpb/telemetry_proto/HuaweiTelemetry.go

# Устанавливаем переменную окружения для использования в Go-скрипте
ENV PROTO_FILES=$PROTO_FILES

# Копируем Go-скрипт в контейнер
COPY generate_paths.go .

# Компилируем Go-скрипт
RUN go build -o generate_paths generate_paths.go

# Запускаем скрипт и сохраняем вывод в файл
RUN ./generate_paths > generated_paths.txt

# (Опционально) Выводим сгенерированный файл для отладки
RUN cat generated_paths.txt

RUN sed -i "\/\/PathKey/r generated_paths.txt" /opt/telegraf/plugins/parsers/huawei_grpc_gpb/telemetry_proto/HuaweiTelemetry.go

RUN cat /opt/telegraf/plugins/parsers/huawei_grpc_gpb/telemetry_proto/HuaweiTelemetry.go
RUN go version

# Переходим в директорию с исходным кодом Telegraf
WORKDIR /opt/telegraf

# Строим Telegraf
RUN make

#RUN sed -i 's#service_address = ":"#service_address = ":57400"#g' telegraf.conf

# Копируем файл конфигурации telegraf
COPY ./telegraf.conf /etc/telegraf/telegraf.conf

# Создаем директории для go cache
RUN mkdir -p /etc/telegraf/.cache && chown -R telegraf:telegraf /etc/telegraf/.cache

# Запускаем Telegraf
CMD ["telegraf"]

