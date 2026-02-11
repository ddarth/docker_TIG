# Using the Telegraf image as a base
#FROM telegraf:latest
FROM golang:1.17.1-buster as git-telegraf-huawei

# Proxy settings (configured via build args from .env)
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY=localhost,127.0.0.1

# Set proxy environment variables (empty by default)
ENV http_proxy="${HTTP_PROXY}"
ENV https_proxy="${HTTPS_PROXY}"
ENV no_proxy="${NO_PROXY}"

# Fix Debian Buster repositories (moved to archive)
RUN sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i 's|security.debian.org|archive.debian.org|g' /etc/apt/sources.list && \
    sed -i '/stretch-updates/d' /etc/apt/sources.list

# Install required dependencies
RUN apt-get \
update && apt-get \
install -y \
    curl \
    unzip \
    make \
    git \
    gcc \
    g++ \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Download and install Go (if errors occur, verify the URLs)
RUN curl -O https://dl.google.com/go/go1.17.1.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.17.1.linux-amd64.tar.gz && \
    rm go1.17.1.linux-amd64.tar.gz

# Install the protoc module
RUN curl -L -o protoc-3.11.4-linux-x86_64.zip https://github.com/protocolbuffers/protobuf/releases/download/v3.11.4/protoc-3.11.4-linux-x86_64.zip && \
    unzip protoc-3.11.4-linux-x86_64.zip -d /usr/local && \
    rm protoc-3.11.4-linux-x86_64.zip

# Set environment variables for Go
ENV GOROOT=/usr/local/go
ENV GOPATH=/usr/local/goWorkplace
ENV PATH=$PATH:$GOROOT/bin:$GOPATH/bin

# Check Go version (for debugging purposes)
RUN go version

# Install the gRPC plugin for Go
RUN go install github.com/golang/protobuf/protoc-gen-go@v1.5.0

# Clone the Telegraf repository
#RUN git clone --branch release-1.20 https://github.com/influxdata/telegraf.git /opt/telegraf
RUN git clone --branch release-1.23 https://github.com/influxdata/telegraf.git /opt/telegraf

# Clone the Telegraf Huawei Plugin repository
RUN git clone https://github.com/HuaweiDatacomm/telegraf-huawei-plugin.git /opt/telegraf-huawei-plugin


# Install required scripts and dependencies for the Telegraf Huawei Plugin
WORKDIR /opt/telegraf-huawei-plugin
ENV TELEGRAFROOT=/opt/telegraf
RUN chmod +x install.sh && ./install.sh

# Copy Huawei proto files
RUN git clone https://github.com/HuaweiDatacomm/proto.git /opt/proto

# Patch *.proto files required for Telegraf compilation
ARG PROTO_FILES="huawei-debug huawei-ifm huawei-twamp-controller"  # Set needed proto files without .proto (at the end)

ARG CACHE_BUST

RUN for file in $PROTO_FILES; do \
        # Copy .proto files to the required directory
        cp /opt/proto/network-router/8.22.0/$file.proto /opt/telegraf/plugins/parsers/huawei_grpc_gpb/telemetry_proto && \
        cd /opt/telegraf/plugins/parsers/huawei_grpc_gpb/telemetry_proto && \
        # Add package name for patching the *.proto file (add "option go_package=/")
        sed -i "/^package \S*;/a option go_package=\"/$file\";" $file.proto && \
        # Generate Go code using protoc based on proto files
        protoc --go_out=plugins=grpc:. $file.proto && \
        # (Optional) Output the contents of the patched file
        echo "Added:" && \
        cat $file.proto | grep go_package &&\
        echo "  to file $file.proto" ; \
    done

RUN ls -l /opt/telegraf/plugins/parsers/huawei_grpc_gpb/telemetry_proto

# Cache-busting hack (passed via a build argument)
ARG CACHE_BUST

# RUN ls -l /opt/telegraf/plugins/parsers/
# RUN ls -l /opt/telegraf/plugins/parsers/huawei_grpc_gpb/
# RUN ls -l
# RUN ls -l /opt/telegraf/plugins/parsers/huawei_grpc_gpb/telemetry_proto
# RUN cat /opt/telegraf/plugins/parsers/huawei_grpc_gpb/telemetry_proto/HuaweiTelemetry.go
# RUN cat /opt/telegraf/plugins/parsers/huawei_grpc_gpb/telemetry_proto/huawei-debug.proto

# Patch HuaweiTelemetry.go to add required modules in the import section
RUN ImportPaths="// Patched by docker"; \
    for file in $PROTO_FILES; do \
        # Create strings with needed format for each file
        ImportPaths="$ImportPaths\n\"github.com/influxdata/telegraf/plugins/parsers/huawei_grpc_gpb/telemetry_proto/$file\"" ; \
    done && \
    echo "$ImportPaths" && \
    sed -i "s#//\"github.com/influxdata/telegraf/plugins/parsers/huawei_grpc_gpb/telemetry_proto/huawei_debug\"#$ImportPaths#" /opt/telegraf/plugins/parsers/huawei_grpc_gpb/telemetry_proto/HuaweiTelemetry.go

# Patch HuaweiTelemetry.go to add required modules in "var pathTypeMap = map[PathKey][]reflect.Type{" section
# Set environment variable for use in the Go script
ENV PROTO_FILES=$PROTO_FILES

# Copy the external Go script for convert class names
COPY generate_paths.go .

# Compile the Go script
RUN go build -o generate_paths generate_paths.go

# Run the script and save its output to a file
RUN ./generate_paths > generated_paths.txt

# (Optional) Output the generated file for debugging
RUN cat generated_paths.txt

RUN sed -i "\/\/PathKey/r generated_paths.txt" /opt/telegraf/plugins/parsers/huawei_grpc_gpb/telemetry_proto/HuaweiTelemetry.go
# (Optional) Output the patched file
RUN cat /opt/telegraf/plugins/parsers/huawei_grpc_gpb/telemetry_proto/HuaweiTelemetry.go


RUN go version

# Change to the Telegraf source code directory
WORKDIR /opt/telegraf

# Build Telegraf
RUN make

FROM telegraf:1.23.4
# Copy the Telegraf configuration file
COPY ./telegraf.conf /etc/telegraf/telegraf.conf
COPY --from=git-telegraf-huawei /opt/telegraf/telegraf /usr/bin/telegraf

# Start Telegraf
CMD ["telegraf"]

