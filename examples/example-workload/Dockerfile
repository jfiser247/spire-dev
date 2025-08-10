# Multi-stage build for Go application with SPIFFE integration
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy go mod and sum files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o spiffe-workload ./cmd/main.go

# Final stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the binary from builder stage
COPY --from=builder /app/spiffe-workload .

# Create non-root user
RUN adduser -D -s /bin/sh appuser

# Change ownership
RUN chown appuser:appuser spiffe-workload

# Switch to non-root user
USER appuser

EXPOSE 8080

CMD ["./spiffe-workload"]