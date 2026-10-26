# Multi-stage build Go API
FROM golang:alpine AS builder

WORKDIR /app

# Install git and ca-certificates
RUN apk add --no-cache git ca-certificates

# Copy go.mod and go.sum first for cache
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Tidy module and build binary
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/kendalaku-api ./cmd/api

# Final runtime image
FROM alpine:3.19

WORKDIR /app

RUN apk add --no-cache ca-certificates tzdata
ENV TZ=UTC

COPY --from=builder /app/kendalaku-api .
COPY --from=builder /app/migrations ./migrations

EXPOSE 8080

CMD ["./kendalaku-api"]
