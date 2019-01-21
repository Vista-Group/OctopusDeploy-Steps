#!/bin/bash

# Creates a generic k8s secret file, from the contents of an octopus variable. 

release_number=$(get_octopusvariable "Octopus.Release.Number")
namespace=$(get_octopusvariable "_namespace")
context=$(get_octopusvariable "_context")
secret_name=$(get_octopusvariable "_secret_name")
secret_file_name=$(get_octopusvariable "_secret_file_name")


PackageRoot=$HOME/.octopus/OctopusServer/Work/tools/$release_number/$namespace
echo "Using PackageTransferPath: $PackageRoot"

echo "Checking secret exists in $namespace"
kubectl --context=$context get secret $secret_name --namespace "$namespace" &>/dev/null
if [ "$?" = "0" ]; then
    echo "Deleting secret in case of changes"
    kubectl --context=$context delete secret $secret_name --namespace "$namespace"  
fi

echo "Creating $secret_name in $namespace"
echo $(get_octopusvariable "_secret_value") > $secret_file_name
kubectl --context=$context create secret generic $secret_name --from-file=$secret_file_name --namespace "$namespace"
rm $secret_file_name
