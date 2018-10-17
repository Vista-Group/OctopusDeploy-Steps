#!/bin/bash

release_number=$(get_octopusvariable "Octopus.Release.Number")
namespace=$(get_octopusvariable "__NAMESPACE")
context=$(get_octopusvariable "__CONTEXT")
# defaults to "traefik-tls-cert"
secret_name=$(get_octopusvariable "__SECRET_NAME")

# Get the configuration (docker compose and environ overrides) from the OctoPackage 'gtp_config'
# Resolve docker templates for a particular stack from manifest
PackageRoot=$HOME/.octopus/OctopusServer/Work/tools/$release_number/$namespace
echo "Using PackageTransferPath: $PackageRoot"


echo "Check TLS secret exists in $namespace"
kubectl --context=$context get secret $secret_name --namespace "$namespace" &>/dev/null
if [ "$?" = "0" ]; then
    echo "TLS Secret $secret_name already exists in $namespace"
else
    echo "TLS Secret $secret_name does not currently exist in $namespace: Adding..."
    cd $PackageRoot

    # This assumes the Octopus certificate was created 
    # from a PEM Cert + PrivateKey
    CERT=$(get_octopusvariable "__CERTIFICATE")
    echo "Cert Name (Octopus Library): $CERT.Name"

    KEY=$CERT.PrivateKeyPem
    echo "$KEY" > $PackageRoot/tls.key
    # check private key with openssl
    openssl rsa -in $PackageRoot/tls.key -check

    CERT=$CERT.CertificatePem
    echo "$CERT" > $PackageRoot/tls.crt
    # check certificate with openssl
    openssl x509 -in $PackageRoot/tls.crt -text -noout
    
    kubectl --context=$context create secret tls "$secret_name" --cert=$PackageRoot/tls.crt --key=$PackageRoot/tls.key --namespace "$namespace"
fi
