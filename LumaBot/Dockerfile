# Stage 1: Build Go application
FROM golang:1.24-alpine AS go-builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -o lumabot

# Stage 2: Final image with Python
FROM python:3.11-slim
WORKDIR /app

# Install Python dependencies
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy Go binary from go-builder
COPY --from=go-builder /app/lumabot ./

# Copy Python application files
COPY main.py .env ./

# Copy startup script
COPY start_services.sh ./
RUN chmod +x start_services.sh

# Set environment variables
ENV PYTHONUNBUFFERED=1

# Expose ports for Go (8080) and Streamlit (8501)
EXPOSE 8080
EXPOSE 8501

# Start both services using the startup script
CMD ["/app/start_services.sh"]