FROM --platform=$BUILDPLATFORM alpine:3.19

# 构建和目标平台参数，用于多架构支持
ARG BUILDPLATFORM=linux/amd64
ARG TARGETPLATFORM=linux/amd64
ARG TARGETARCH=amd64
# 安装必要的依赖（tzdata用于TZ环境变量）
RUN { [ -n "${http_proxy}" ] && echo "Using proxy: ${http_proxy}" || true; } \
    && apk add --no-cache curl bash wget gzip tar tzdata dcron \
    && rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* /var/cache/apt/archives/*

# 设置工作目录
WORKDIR /clash-for-linux

# 复制tool文件夹到临时位置用于多架构构建
COPY tool /tmp/tools

# 从本地tool文件夹复制Clash Meta二进制文件
RUN MIHOMO_VERSION="v1.19.22" && \
    case ${TARGETARCH} in \
        amd64) \
            CLASH_ARCH="linux-amd64" ;; \
        arm64) \
            CLASH_ARCH="linux-arm64" ;; \
        arm) \
            CLASH_ARCH="linux-armv7" ;; \
        *) \
            echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    mkdir -p /usr/local/bin && \
    # mihomo-linux-amd64-v1.19.22
    cp /tmp/tools/mihomo-${CLASH_ARCH}-${MIHOMO_VERSION}.gz /tmp/clash.gz && \
    gunzip /tmp/clash.gz && \
    mv /tmp/clash /usr/local/bin/clash && \
    chmod +x /usr/local/bin/clash && \
    echo "Mihomo ${MIHOMO_VERSION} for ${TARGETARCH} installed as /usr/local/bin/clash"

# 从本地tool文件夹复制并解压MetaCubeXD仪表板
RUN METACUBEXD_VERSION="v1.241.0" && \
    mkdir -p /root/.config/clash/dashboard && \
    tar -xzf /tmp/tools/compressed-dist.tgz -C /root/.config/clash/dashboard/ && \
    echo "MetaCubeXD dashboard ${METACUBEXD_VERSION} extracted"

# 从本地tool文件夹复制GeoIP数据库
RUN mkdir -p /root/.config/clash && \
    cp /tmp/tools/geoip.metadb /root/.config/clash/geoip.metadb && \
    echo "GeoIP database copied: $(ls -lh /root/.config/clash/geoip.metadb | awk '{print $5}')"


# 从本地tool文件夹复制subconverter
RUN SUBCONVERTER_VERSION="v0.9.0" && \
    case ${TARGETARCH} in \
        amd64) \
            SUBCONVERTER_ARCH="linux64" ;; \
        arm64) \
            SUBCONVERTER_ARCH="aarch64" ;; \
        arm) \
            SUBCONVERTER_ARCH="armv7" ;; \
        *) \
            echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    mkdir -p /app/tools && \
    tar -xzf /tmp/tools/subconverter_${SUBCONVERTER_ARCH}.tar.gz -C /app/tools && \
    chmod +x /app/tools/subconverter/subconverter && \
    echo "Subconverter ${SUBCONVERTER_VERSION} for ${TARGETARCH} installed"

# 复制配置文件
COPY config/config.yaml.example /config/config.yaml.example

# 暴露必要的端口（根据需要调整）
EXPOSE 7890 7891 9090

# 复制healthcheck脚本并用于Docker HEALTHCHECK
COPY scripts/*.sh /app/scripts/
RUN chmod +x /app/scripts/*.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD ["/bin/sh", "/app/scripts/healthcheck.sh"]

# 设置入口点
ENTRYPOINT ["/app/scripts/entrypoint.sh"]
