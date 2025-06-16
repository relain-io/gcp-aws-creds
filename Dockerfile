# Build Stage
FROM golang:1.24-alpine AS builder
ENV CGO_ENABLED=0

WORKDIR /app

# Copy go mod and sum files
COPY go.mod go.sum ./
RUN go mod download

# Copy the source code
COPY . .

# Build the Go app
RUN go build -o gcp-aws-creds .

### Runtime Image
FROM alpine:latest
WORKDIR /

# Copy the built binary from builder
COPY --from=builder /app/gcp-aws-creds .

# Set the entrypoint
ENTRYPOINT ["./gcp-aws-creds"]
