# generateCerts
Scripts to generate local certifications that are acceptable to browsers

# How to

you may have to mark the script executable.

    chmod +x generate_local_certs.sh

Then you can run it with your domain.

    ./generate_local_certs.sh <local.mydomain.com>

where <local..domain> is replaced with your actual local domain.  Then just follow the instructions based on your OS. For chrome, you can also use Settings->Security->Certificates->Manage certificates to get to the system method of adding the certificate. Then you need to import it into Trusted. 

GLHF.
