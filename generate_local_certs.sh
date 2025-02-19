#!/usr/bin/env bash

if [ -z "$1" ]
then
    echo "Please supply a domain to create certificates for"
    echo "e.g. ./generate_local_certs.sh mydomain.com"
    exit 1
fi

DOMAIN=$1
CERT_DIR="certs"
mkdir -p $CERT_DIR

# Generate Root CA
echo "Generating Root CA..."
openssl genrsa -out $CERT_DIR/rootCA.key 2048

openssl req -x509 -new -nodes -key $CERT_DIR/rootCA.key -sha256 -days 3650 \
    -out $CERT_DIR/rootCA.pem \
    -subj "/C=US/ST=Local/L=Local/O=Development/CN=Local Development Root CA"

# Create v3.ext file for SAN
cat > $CERT_DIR/v3.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = *.$DOMAIN
EOF

# Generate Domain Certificate
echo "Generating certificate for *.$DOMAIN..."
openssl genrsa -out $CERT_DIR/local-key.key 2048

openssl req -new -key $CERT_DIR/local-key.key \
    -out $CERT_DIR/local.csr \
    -subj "/C=US/ST=Local/L=Local/O=Development/CN=*.$DOMAIN"

openssl x509 -req -in $CERT_DIR/local.csr \
    -CA $CERT_DIR/rootCA.pem \
    -CAkey $CERT_DIR/rootCA.key \
    -CAcreateserial \
    -out $CERT_DIR/local-cert.crt \
    -days 825 \
    -sha256 \
    -extfile $CERT_DIR/v3.ext

# Cleanup
rm $CERT_DIR/local.csr
rm $CERT_DIR/v3.ext

echo "
Certificates generated successfully!

Files created in $CERT_DIR/:
- rootCA.pem (Root CA certificate to trust)
- rootCA.key (Root CA private key)
- local-cert.crt (Domain certificate)
- local-key.key (Domain private key)

To trust these certificates:

1. Import rootCA.pem into your system's trust store
   - On macOS: Add to Keychain Access and trust it
   - On Linux: Copy to /usr/local/share/ca-certificates/ and run update-ca-certificates
   - On Windows: Import to Certificate Manager under Trusted Root Certification Authorities

2. Update your Traefik configuration to use:
   - Certificate: $CERT_DIR/local-cert.crt
   - Private key: $CERT_DIR/local-key.key

Your certificates will be valid for *.${DOMAIN}
"
