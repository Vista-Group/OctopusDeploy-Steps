#!/bin/bash

release_number=$(get_octopusvariable "Octopus.Release.Number")
namespace=$(get_octopusvariable "__NAMESPACE")
configmap=$(get_octopusvariable "__STACK")
context=$(get_octopusvariable "__CONTEXT")
multiClusterDeployment=$(get_octopusvariable "__MULTICLUSTERDEPLOYMENT")

roll_configmap() {
	write_verbose "check existance of configmap $1"
	kubectl --context=$context get configmap "$1" --namespace $namespace &>/dev/null
	
	if [ "$?" = "0" ]; then
			write_verbose "Configmap $1 exists, removing..."
			kubectl --context=$context delete configmap "$1" --namespace $namespace
	fi

	write_verbose "create configmap $1 in namespace $namespace"
	write_verbose "For the env file at $2"
	kubectl --context=$context create configmap "$1" --namespace $namespace --from-env-file=$2
}

# Get the configuration (docker compose and environ overrides) from the OctoPackage 'gtp_config'
# Resolve docker templates for a particular stack from manifest
PackageRoot=$HOME/.octopus/OctopusServer/Work/tools/$release_number/$namespace
write_verbose "Using PackageTransferPath: $PackageRoot"

# If the ingress is a multi cluster deployment
if [ "$multiClusterDeployment" == "true" ] || [ "$multiClusterDeployment" == "True" ] ; then
    echo "The deployment has common/shared config for more than one cluster: $multiClusterDeployment"
    envDir="$namespace/$context"
    
else #Otherwise, do the standard single cluster deployment
    echo "The deployment has particular config for each cluster: $multiClusterDeployment"
    envDir="$namespace"
fi

echo "Common  ConfigMap will be created from : environments/common.env"
echo "Environ ConfigMap will be created from : environments/$envDir/$namespace.env"
echo "Stack   ConfigMap will be created from : environments/$envDir/$configmap.env"

# Add the new config maps for and global, environ and stack variables
#THIS config-maps will be eventually deprecated
roll_configmap "global-$configmap-config" "$PackageRoot/environments/common.env"
roll_configmap "$configmap-config" "$PackageRoot/environments/$envDir/$configmap.env"

#THIS config-maps maps will replace the ones above
roll_configmap "common-$namespace-config" "$PackageRoot/environments/common.env"
roll_configmap "stack-$configmap-config" "$PackageRoot/environments/$envDir/$namespace.env"

for fullfile in $PackageRoot/services/*.env; do
      roll_configmap "$(basename "$fullfile" .env)-config" "$fullfile"
done
