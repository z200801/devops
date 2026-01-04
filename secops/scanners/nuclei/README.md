# Nuclei Scanner Docker

Docker container for running [Nuclei](https://github.com/projectdiscovery/nuclei) vulnerability scanner with multistage build for minimal image size.

## Features

- Multistage Docker build for optimized image size
- Ubuntu-based final image
- Latest Nuclei version (v3.6.2)
- Pre-configured templates (~9000+ templates)
- Makefile for easy management
- Volume mounting for results persistence
- Support for scanning local and remote targets

## Prerequisites

- Docker
- Make (optional, but recommended)

## Quick Start

### Build the Image

```bash
make build
```

### Verify Installation

```bash
# Check templates are loaded
make verify-templates

# Run help
make run
```

### Scan a Target

```bash
# Scan single target
make scan TARGET_URL=https://example.com

# Scan with specific tags
make scan-cve TARGET_URL=https://example.com
make scan-exposures TARGET_URL=https://example.com
make scan-misconfig TARGET_URL=https://example.com
```

## Makefile Commands

| Command | Description | Example |
|---------|-------------|---------|
| `make help` | Show all available commands with examples | `make help` |
| `make build` | Build Docker image | `make build` |
| `make verify-templates` | Verify templates are installed | `make verify-templates` |
| `make run` | Display Nuclei help | `make run` |
| `make scan` | Scan single target with all templates | `make scan TARGET_URL=https://example.com` |
| `make scan-list` | Scan from targets file | `make scan-list TARGET_FILE=targets.txt` |
| `make scan-cve` | Scan for CVEs only | `make scan-cve TARGET_URL=https://example.com` |
| `make scan-exposures` | Scan for exposures | `make scan-exposures TARGET_URL=https://example.com` |
| `make scan-misconfig` | Scan for misconfigurations | `make scan-misconfig TARGET_URL=https://example.com` |
| `make scan-severity` | Scan with severity filter | `make scan-severity SEVERITY=critical,high` |
| `make update-templates` | Update Nuclei templates | `make update-templates` |
| `make clean` | Remove results and Docker image | `make clean` |
| `make clean-results` | Remove results only | `make clean-results` |

## Configuration

### Makefile Variables

You can customize the following variables when running make commands:

```bash
IMAGE_NAME=nuclei-scanner    # Docker image name
TAG=latest                   # Image tag
RESULTS_DIR=./results        # Results directory
TARGET_URL=http://localhost  # Target URL
TARGET_FILE=targets.txt      # Targets file
SEVERITY=critical,high       # Severity filter
```

### Usage Examples

#### Scan Single Target

```bash
make scan TARGET_URL=https://example.com
```

#### Scan Multiple Targets

Create `targets.txt`:
```
https://example.com
https://test.com
https://demo.com
```

Run scan:
```bash
make scan-list TARGET_FILE=targets.txt
```

#### Scan with Custom Severity

```bash
make scan-severity TARGET_URL=https://example.com SEVERITY=medium,high,critical
```

#### Scan Specific Categories

```bash
# CVEs only
make scan-cve TARGET_URL=https://example.com

# Information exposures
make scan-exposures TARGET_URL=https://example.com

# Misconfigurations
make scan-misconfig TARGET_URL=https://example.com
```

#### Use Custom Image Name

```bash
IMAGE_NAME=my-nuclei make scan TARGET_URL=https://example.com
```

## Testing with Vulnerable Docker Images

To test Nuclei's capabilities, you can use deliberately vulnerable applications. 

**⚠️ WARNING: These images contain real vulnerabilities. Never expose them to the internet or production networks!**

### Available Vulnerable Applications

#### 1. DVWA (Damn Vulnerable Web Application)

**Best for**: Beginners, PHP vulnerabilities, classic web attacks

```bash
# Pull and run DVWA
docker pull vulnerables/web-dvwa
docker run -d --name dvwa -p 8080:80 vulnerables/web-dvwa

# Initialize DVWA (required!)
# 1. Open http://localhost:8080 in browser
# 2. Click "Create / Reset Database"
# 3. Login: admin / password

# Scan DVWA
make scan TARGET_URL=http://YOUR_IP:8080
```

**Size**: ~712MB  
**Contains**: SQL Injection, XSS, Command Injection, File Upload, CSRF, and more

#### 2. OWASP Juice Shop

**Best for**: Modern applications, JavaScript/Node.js, complex business logic vulnerabilities

```bash
# Pull and run Juice Shop
docker pull bkimminich/juice-shop
docker run -d --name juiceshop -p 3000:3000 bkimminich/juice-shop

# Scan Juice Shop
make scan TARGET_URL=http://YOUR_IP:3000
```

**Size**: ~500MB  
**Contains**: OWASP Top 10, API vulnerabilities, modern web app issues

#### 3. WebGoat

**Best for**: Java applications, educational purposes, OWASP lessons

```bash
# Pull and run WebGoat
docker pull webgoat/webgoat
docker run -d --name webgoat -p 8080:8080 -p 9090:9090 webgoat/webgoat

# Scan WebGoat
make scan TARGET_URL=http://YOUR_IP:8080
```

**Size**: ~400MB  
**Contains**: Java-specific vulnerabilities, OWASP Top 10 with tutorials

#### 4. bWAPP

**Best for**: Comprehensive vulnerability collection, CTF practice

```bash
# Run bWAPP
docker run -d --name bwapp -p 8080:80 raesene/bwapp

# Scan bWAPP
make scan TARGET_URL=http://YOUR_IP:8080
```

**Size**: ~300MB  
**Contains**: 100+ vulnerabilities across all categories

### Complete Testing Workflow

```bash
# 1. Start vulnerable application
docker run -d --name dvwa -p 8080:80 vulnerables/web-dvwa

# 2. Initialize if needed (DVWA requires database setup)

# 3. Find your IP address
ip addr show | grep inet
# Or use: hostname -I

# 4. Run comprehensive scan
make scan TARGET_URL=http://192.168.1.65:8080

# 5. Run targeted scans
make scan-cve TARGET_URL=http://192.168.1.65:8080
make scan-exposures TARGET_URL=http://192.168.1.65:8080
make scan-misconfig TARGET_URL=http://192.168.1.65:8080

# 6. Check results
cat results/scan-results.txt
cat results/cve-scan.txt
cat results/exposures-scan.txt

# 7. Clean up when done
docker stop dvwa
docker rm dvwa
```

### Expected Results by Application

| Application | CVEs | Exposures | Misconfigurations | Typical Findings |
|-------------|------|-----------|-------------------|------------------|
| DVWA | Low | Medium | High | Missing security headers, weak cookies, default configs |
| Juice Shop | Low | Medium | High | API exposure, metrics endpoint, missing headers |
| WebGoat | Low-Medium | Medium | Medium | Educational vulnerabilities, Java-specific issues |
| bWAPP | Low-Medium | High | High | Comprehensive vulnerability set |

### Scanning Local Applications

When scanning applications running on your local machine, use your actual IP address instead of `localhost`:

```bash
# Find your IP
ip addr show | grep "inet "

# Scan using your IP
make scan TARGET_URL=http://192.168.1.65:8080
```

**Why not localhost?** 
Docker containers cannot access the host's `localhost` directly. You must use:
- Your machine's IP address (e.g., `192.168.1.65`)
- Or use `--network="host"` flag (advanced)

### Security Best Practices

1. **Never expose vulnerable containers to the internet**
   - Bind only to localhost: `-p 127.0.0.1:8080:80`
   - Or use your LAN IP for isolated testing

2. **Stop and remove containers after testing**
   ```bash
   docker stop dvwa juiceshop webgoat
   docker rm dvwa juiceshop webgoat
   ```

3. **Use isolated networks**
   ```bash
   docker network create security-lab
   docker run --network security-lab ...
   ```

4. **Monitor resource usage**
   ```bash
   docker stats
   ```

## Advanced Usage

### Custom Templates

Mount your custom templates directory:

```bash
docker run --rm \
  -v $(pwd)/results:/output \
  -v $(pwd)/custom-templates:/custom \
  nuclei-scanner:latest \
  -u https://example.com \
  -t /custom \
  -o /output/custom-scan.txt
```

### Rate Limiting

```bash
docker run --rm \
  -v $(pwd)/results:/output \
  nuclei-scanner:latest \
  -u https://example.com \
  -rate-limit 100 \
  -o /output/scan-results.txt
```

### JSON Output

```bash
docker run --rm \
  -v $(pwd)/results:/output \
  nuclei-scanner:latest \
  -u https://example.com \
  -json \
  -o /output/scan-results.json
```

### Silent Mode (Only Results)

```bash
docker run --rm \
  -v $(pwd)/results:/output \
  nuclei-scanner:latest \
  -u https://example.com \
  -silent \
  -o /output/scan-results.txt
```

### Verbose Output

```bash
docker run --rm \
  -v $(pwd)/results:/output \
  nuclei-scanner:latest \
  -u https://example.com \
  -v \
  -o /output/scan-results.txt
```

## Understanding Scan Results

### Severity Levels

- **Critical** - Immediate action required (RCE, authentication bypass)
- **High** - High priority (SQL injection, XSS with auth bypass)
- **Medium** - Medium priority (misconfigurations, information disclosure)
- **Low** - Low priority (minor issues)
- **Info** - Informational (version detection, fingerprinting)

### Common Findings

| Finding | Severity | Description |
|---------|----------|-------------|
| Missing security headers | Info/Low | Missing CSP, HSTS, X-Frame-Options |
| Exposed API documentation | Info/Medium | Swagger/OpenAPI exposed |
| Exposed metrics | Medium | Prometheus/monitoring endpoints |
| Default credentials | High/Critical | Default admin passwords |
| Known CVEs | Varies | Outdated software vulnerabilities |

### Result Files

All scan results are saved in the `./results` directory:

```
results/
├── scan-results.txt       # Full scan results
├── cve-scan.txt          # CVE-specific scan
├── exposures-scan.txt    # Exposure scan
├── misconfig-scan.txt    # Misconfiguration scan
└── severity-scan.txt     # Severity-filtered scan
```

## Project Structure

```
.
├── Dockerfile          # Multistage Docker build
├── Makefile           # Build and run automation
├── README.md          # This file
├── results/           # Scan results (created automatically)
└── targets.txt        # Target list (optional)
```

## Troubleshooting

### Templates Not Loading

```bash
# Rebuild image
make clean
make build

# Verify templates
make verify-templates
```

### Cannot Access Target

```bash
# Check target is accessible
curl -I http://target-url

# Use correct IP address (not localhost from container)
ip addr show | grep inet

# Test connectivity
docker run --rm curlimages/curl:latest curl -I http://YOUR_IP:8080
```

### Permission Issues

```bash
# Fix results directory permissions
sudo chown -R $USER:$USER results/
```

### Rate Limiting

If scans are too slow or too fast:

```bash
# Slower scan (careful with rate limits)
docker run ... nuclei-scanner -rate-limit 50 ...

# Faster scan (may trigger WAF)
docker run ... nuclei-scanner -rate-limit 300 ...
```

## What Nuclei Can Find

### ✅ Nuclei Detects

- Known CVEs in software versions
- Exposed sensitive files (.git, .env, backups)
- Misconfigurations (CORS, headers, permissions)
- Default credentials
- API endpoints and documentation
- Information disclosure
- Technology fingerprinting
- Common web vulnerabilities with clear signatures

### ❌ Nuclei Does NOT Detect

- Logic flaws in application code
- Zero-day vulnerabilities
- Complex multi-step attacks
- Authentication/authorization bugs requiring business logic understanding
- Social engineering vulnerabilities
- Custom application-specific issues

For comprehensive security testing, combine Nuclei with:
- Manual penetration testing
- Dynamic application security testing (DAST)
- Static application security testing (SAST)
- Security code review

## Performance Considerations

- **Full scan**: 1-10 minutes depending on target
- **CVE scan**: 10-30 seconds
- **Targeted scans**: 30 seconds - 2 minutes
- **Templates loaded**: ~9000+
- **Memory usage**: ~200-500MB during scan
- **Network bandwidth**: Varies by target response time

## Updates

### Update Nuclei Templates

```bash
make update-templates
```

### Rebuild with Latest Nuclei

```bash
make clean
make build
```

## Security Notes

- Run scans **only on targets you own** or have permission to test
- Be aware of rate limiting and target load
- Review severity levels before taking action
- Keep templates updated regularly
- Never run vulnerable test applications in production
- Use isolated networks for testing

## Contributing

Improvements and suggestions are welcome! Common areas:

- Additional Makefile targets
- Custom template examples
- Integration with CI/CD pipelines
- Output parsing scripts

## License

This project configuration is provided as-is. Nuclei is licensed under MIT License by ProjectDiscovery.

## Links

- [Nuclei Official Repository](https://github.com/projectdiscovery/nuclei)
- [Nuclei Documentation](https://docs.projectdiscovery.io/tools/nuclei/overview)
- [Nuclei Templates](https://github.com/projectdiscovery/nuclei-templates)
- [DVWA](https://github.com/digininja/DVWA)
- [OWASP Juice Shop](https://owasp.org/www-project-juice-shop/)
- [WebGoat](https://owasp.org/www-project-webgoat/)

## Support

For issues related to:
- **This Docker setup**: Open an issue in this repository
- **Nuclei itself**: Visit [Nuclei GitHub](https://github.com/projectdiscovery/nuclei)
- **Vulnerable applications**: Check their respective documentation

---

**Remember**: This is a security testing tool. Always obtain proper authorization before scanning any systems you don't own.
