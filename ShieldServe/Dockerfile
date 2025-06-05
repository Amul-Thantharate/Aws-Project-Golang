# Stage 1: Build the Go application
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Install git for dependency management
RUN apk add --no-cache git

# Download dependencies first (for layer caching)
COPY go.mod go.sum ./
RUN go mod download 

# Copy source code
COPY . .

# Build static binary
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o /app/main .

# Stage 2: Create minimal runtime image
FROM alpine:3.18

WORKDIR /app

# Install SQLite and create database
RUN apk add --no-cache sqlite && \
    mkdir -p /data && \
    sqlite3 /data/app.db " \
      CREATE TABLE IF NOT EXISTS users ( \
        id INTEGER PRIMARY KEY AUTOINCREMENT, \
        username VARCHAR(50) NOT NULL UNIQUE, \
        password VARCHAR(100) NOT NULL, \
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP \
      ); \
      INSERT OR IGNORE INTO users (username, password) VALUES ('admin', '\$2a\$10\$ExampleHash'); \
    "

# Copy pre-built binary
COPY --from=builder /app/main /app/main

# Create templates directory if needed
RUN mkdir -p /app/templates

# Set permissions
RUN chmod +x /app/main && \
    chown -R nobody:nobody /data /app

# Runtime configuration
USER nobody
ENV SQLITE_PATH=/data/app.db
EXPOSE 8080

CMD ["/app/main"]