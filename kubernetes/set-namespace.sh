#!/bin/bash

export releaseNumber=`get_octopusvariable "Octopus.Release.Number"`
export namespace=`get_octopusvariable "namespace"`
export context=`get_octopusvariable "__CONTEXT"`
export dockerRegistryEmail=`get_octopusvariable "dockerRegistryEmail"`
export dockerRegistryPassword=`get_octopusvariable "dockerRegistryPassword"`
export dockerRegistryServer=`get_octopusvariable "dockerRegistryServer"`
export dockerRegistryUsername=`get_octopusvariable "dockerRegistryUsername"`

# Get the configuration (docker compose and environ overrides) from the OctoPackage 'gtp_config'
# Resolve docker templates for a particular stack from manifest
PackageRoot=$HOME/.octopus/OctopusServer/Work/tools/$releaseNumber/$namespace
echo "Using PackageTransferPath: $PackageRoot"

#TODO check for changes with md5sum or something
echo "check existance of namespace $namespace"
kubectl --context=$context get namespace "$namespace" &>/dev/null
if [ "$?" = "0" ]; then
        #delete
		echo "namespace $namespace already exists "
else
	# create
	echo "create configmap $configmap-config "
    kubetpl render $PackageRoot/environments/namespace.yaml -s NAMESPACE=$namespace | cat -
    kubetpl render $PackageRoot/environments/namespace.yaml -s NAMESPACE=$namespace | kubectl --context=$context create -f -
fi

echo "Check registry secret exists in $namespace"
kubectl --context=$context get secret regsecret --namespace "$namespace" &>/dev/null
if [ "$?" = "0" ]; then
    echo "Registry Secret regsecret already exists in $namespace"
else
    write-highlight "Registry Secret does not currently exist in $namespace. Adding..."
    kubectl --context=$context create secret docker-registry regsecret --docker-server=$dockerRegistryServer --docker-username=$dockerRegistryUsername --docker-password=$dockerRegistryPassword --docker-email=$dockerRegistryEmail --namespace "$namespace"
fi
