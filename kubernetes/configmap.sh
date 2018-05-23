#!/bin/bash

export releaseNumber=`get_octopusvariable "Octopus.Release.Number"`
export namespace=`get_octopusvariable "__NAMESPACE"`
export configmap=`get_octopusvariable "__STACK"`
export context=`get_octopusvariable "__CONTEXT"`
export multiClusterDeployment=`get_octopusvariable "__MULTICLUSTERDEPLOYMENT"`

create_configmap() {
	write_verbose "create configmap $1 in namespace $namespace"
	write_verbose "For the env file at $2"
	kubectl --context=$context create configmap "$1" --namespace $namespace --from-env-file=$2
}

# Get the configuration (docker compose and environ overrides) from the OctoPackage 'gtp_config'
# Resolve docker templates for a particular stack from manifest
PackageRoot=$HOME/.octopus/OctopusServer/Work/tools/$releaseNumber/$namespace
write_verbose "Using PackageTransferPath: $PackageRoot"

# If the ingress is a multi cluster deployment
if [ "$multiClusterDeployment" == "true" ]; then
    envDir="$namespace/$context"
else #Otherwise, do the standard single cluster deployment
    envDir="$namespace"
fi

# Add the new config maps for local and global variables
create_configmap "$configmap-config" "$PackageRoot/environments/$envDir/$configmap.env"
create_configmap "global-$configmap-config" "$PackageRoot/environments/common.env"
