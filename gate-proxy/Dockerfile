# Multi-stage build for Gate proxy
FROM golang:1.23-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o gate-proxy .

# Final stage
FROM alpine:latest
RUN apk --no-cache add ca-certificates tzdata
WORKDIR /root/

COPY --from=builder /app/gate-proxy .
COPY gate_config.yaml ./

# Gate proxy runs on port 25565
EXPOSE 25565

CMD ["./gate-proxy"]