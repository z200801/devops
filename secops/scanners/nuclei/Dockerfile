# Stage 1: Builder
FROM golang:1.24-bookworm AS builder

# Install Nuclei
RUN go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest

# Stage 2: Final image
FROM ubuntu:22.04

# Install minimal dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy nuclei binary from builder stage
COPY --from=builder /go/bin/nuclei /usr/local/bin/nuclei

# Create output directory
RUN mkdir -p /output/root/nuclei-templates \
    && nuclei -update-templates \
    && nuclei -tl || echo "Templates location check"

WORKDIR /output

ENTRYPOINT ["nuclei"]
CMD ["-h"]
