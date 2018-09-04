#!/bin/bash

release_number=$(get_octopusvariable "Octopus.Release.Number")
namespace=$(get_octopusvariable "namespace")
context=$(get_octopusvariable "__CONTEXT")
dockerRegistryEmail=$(get_octopusvariable "dockerRegistryEmail")
dockerRegistryPassword=$(get_octopusvariable "dockerRegistryPassword")
dockerRegistryServer=$(get_octopusvariable "dockerRegistryServer")
dockerRegistryUsername=$(get_octopusvariable "dockerRegistryUsername")

# Get the configuration (docker compose and environ overrides) from the OctoPackage 'gtp_config'
# Resolve docker templates for a particular stack from manifest
PackageRoot=$HOME/.octopus/OctopusServer/Work/tools/$release_number/$namespace
echo "Using PackageTransferPath: $PackageRoot"

#TODO check for changes with md5sum or something
echo "check existance of namespace $namespace"
kubectl --context=$context get namespace "$namespace" &>/dev/null
if [ "$?" = "0" ]; then
        #delete
		echo "namespace $namespace already exists "
else
	# create
	echo "create $namespace namespace"
    kubetpl render $PackageRoot/environments/namespace.yaml -s NAMESPACE=$namespace | cat -
    kubetpl render $PackageRoot/environments/namespace.yaml -s NAMESPACE=$namespace | kubectl --context=$context create -f -
fi

echo "Check registry secret exists in $namespace"
kubectl --context=$context get secret regsecret --namespace "$namespace" &>/dev/null
if [ "$?" = "0" ]; then
    echo "Registry Secret regsecret already exists in $namespace"
else
    write_highlight "Registry Secret does not currently exist in $namespace. Adding..."
    kubectl --context=$context create secret docker-registry regsecret --docker-server=$dockerRegistryServer --docker-username=$dockerRegistryUsername --docker-password=$dockerRegistryPassword --docker-email=$dockerRegistryEmail --namespace "$namespace"
fi
