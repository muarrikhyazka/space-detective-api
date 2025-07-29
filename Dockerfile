# Multi-stage build for Space Detective API
FROM alibaba-cloud-linux-3-registry.cn-hangzhou.cr.aliyuncs.com/alinux3/alinux3:latest as builder

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Install Python 3.11 and dependencies
RUN yum update -y && \
    yum install -y python3.11 python3.11-pip python3.11-devel \
    gcc gcc-c++ make \
    postgresql-devel \
    && yum clean all

# Set work directory
WORKDIR /app

# Copy requirements
COPY requirements.txt .

# Create symlinks for python and pip
RUN ln -sf /usr/bin/python3.11 /usr/bin/python && \
    ln -sf /usr/bin/pip3.11 /usr/bin/pip

# Configure pip to use Alibaba Cloud mirrors for faster downloads
RUN pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/ && \
    pip config set global.trusted-host mirrors.aliyun.com

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Production stage
FROM alibaba-cloud-linux-3-registry.cn-hangzhou.cr.aliyuncs.com/alinux3/alinux3:latest

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app

# Install Python 3.11 runtime and dependencies
RUN yum update -y && \
    yum install -y python3.11 python3.11-pip \
    postgresql-libs \
    && yum clean all \
    && useradd --create-home --shell /bin/bash app

# Create symlinks for python and pip
RUN ln -sf /usr/bin/python3.11 /usr/bin/python && \
    ln -sf /usr/bin/pip3.11 /usr/bin/pip

# Copy Python packages from builder
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Set work directory
WORKDIR /app

# Copy application code
COPY chatbot/ ./chatbot/
COPY requirements.txt .

# Change ownership to app user
RUN chown -R app:app /app

# Switch to non-root user
USER app

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8000/api/health')" || exit 1

# Set default working directory to trial
WORKDIR /app/chatbot/trial

# Command to run the application
CMD ["/usr/bin/python3.11", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]