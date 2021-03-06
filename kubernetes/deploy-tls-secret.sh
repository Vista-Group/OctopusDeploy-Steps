#!/bin/bash

release_number=$(get_octopusvariable "Octopus.Release.Number")
namespace=$(get_octopusvariable "__NAMESPACE")
context=$(get_octopusvariable "__CONTEXT")

#defaults to OriginCertificate
certificate_name=$(get_octopusvariable "__CERTIFICATE_NAME")

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
    CERTNAME=$(get_octopusvariable "$certificate_name".Name)
    echo "Cert Name (In Octopus Library): $CERTNAME"

    KEY=$(get_octopusvariable "$certificate_name".PrivateKeyPem)
    echo "$KEY" > $PackageRoot/tls.key
    # check private key with openssl
    openssl rsa -in $PackageRoot/tls.key -check

    CERT=$(get_octopusvariable "$certificate_name".CertificatePem)
    echo "$CERT" > $PackageRoot/tls.crt
    # check certificate with openssl
    openssl x509 -in $PackageRoot/tls.crt -text -noout
    
    openssl x509 -in $PackageRoot/cacerts/DigiCert_High_Assurance_EV_Root_CA.crt -text -noout
    openssl x509 -in $PackageRoot/cacerts/DigiCert_SHA2_High_Assurance_Server_CA.crt -text -noout

    traffic_type=$(get_octopusvariable "__TRAFFIC_TYPE")
    if [ "$traffic_type" == "api" ]
    then
        echo "adding the full chain of certs"
        cat $PackageRoot/cacerts/DigiCert_High_Assurance_EV_Root_CA.crt >> $PackageRoot/tls.crt
        cat $PackageRoot/cacerts/DigiCert_SHA2_High_Assurance_Server_CA.crt >> $PackageRoot/tls.crt
    fi
    
    kubectl --context=$context create secret tls "$secret_name" --cert=$PackageRoot/tls.crt --key=$PackageRoot/tls.key --namespace "$namespace"
    kubectl --context=$context label secret "$secret_name" traffic-type="$traffic_type" -n "$namespace"
fi
