#!/usr/bin/env bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Helper function for section headers
print_section() {
    echo -e "${BLUE}${BOLD}=== $1 ===${NC}"
}

# Helper function for success messages
print_success() {
    echo -e "${GREEN}✔ $1${NC}"
}

# Helper function for info messages
print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Helper function for error messages
print_error() {
    echo -e "${RED}✘ $1${NC}"
}

if [ -z "$1" ]
then
    print_error "Please supply a domain to create certificates for"
    print_info "Usage: ./generate_local_certs.sh mydomain.com"
    exit 1
fi

DOMAIN=$1
CERT_DIR="certs"
mkdir -p $CERT_DIR

# Generate Root CA
print_section "Generating Root CA"
openssl genrsa -out $CERT_DIR/rootCA.key 2048 2>/dev/null
print_success "Generated Root CA key"

openssl req -x509 -new -nodes -key $CERT_DIR/rootCA.key -sha256 -days 3650 \
    -out $CERT_DIR/rootCA.pem \
    -subj "/C=US/ST=Local/L=Local/O=Development/CN=Local Development Root CA" 2>/dev/null
print_success "Generated Root CA certificate"

# Create v3.ext file for SAN
print_section "Creating certificate configuration"
cat > $CERT_DIR/v3.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = *.$DOMAIN
EOF
print_success "Created v3.ext configuration file"

# Generate Domain Certificate
print_section "Generating certificate for *.$DOMAIN"
openssl genrsa -out $CERT_DIR/local-key.key 2048 2>/dev/null
print_success "Generated domain private key"

openssl req -new -key $CERT_DIR/local-key.key \
    -out $CERT_DIR/local.csr \
    -subj "/C=US/ST=Local/L=Local/O=Development/CN=*.$DOMAIN" 2>/dev/null
print_success "Generated certificate signing request"

openssl x509 -req -in $CERT_DIR/local.csr \
    -CA $CERT_DIR/rootCA.pem \
    -CAkey $CERT_DIR/rootCA.key \
    -CAcreateserial \
    -out $CERT_DIR/local-cert.crt \
    -days 825 \
    -sha256 \
    -extfile $CERT_DIR/v3.ext 2>/dev/null
print_success "Generated domain certificate"

# Cleanup
rm $CERT_DIR/local.csr
rm $CERT_DIR/v3.ext
print_success "Cleaned up temporary files"

echo -e "
${GREEN}${BOLD}Certificates generated successfully!${NC}

${BOLD}Files created in ${BLUE}$CERT_DIR/${NC}:
${YELLOW}├─ rootCA.pem${NC} (Root CA certificate to trust)
${YELLOW}├─ rootCA.key${NC} (Root CA private key)
${YELLOW}├─ local-cert.crt${NC} (Domain certificate)
${YELLOW}└─ local-key.key${NC} (Domain private key)

${BOLD}To trust these certificates:${NC}

${BLUE}1. Import rootCA.pem into your system's trust store${NC}
   ${YELLOW}• macOS:${NC} Add to Keychain Access and trust it
   ${YELLOW}• Linux:${NC} Copy to /usr/local/share/ca-certificates/ and run update-ca-certificates
   ${YELLOW}• Windows:${NC} Import to Certificate Manager under Trusted Root Certification Authorities

${BLUE}2. Update your Traefik configuration to use:${NC}
   ${YELLOW}• Certificate:${NC} $CERT_DIR/local-cert.crt
   ${YELLOW}• Private key:${NC} $CERT_DIR/local-key.key

${GREEN}Your certificates will be valid for *.${DOMAIN}${NC}
"
