#!/bin/bash

export releaseNumber=`get_octopusvariable "Octopus.Release.Number"`
export namespace=`get_octopusvariable "__NAMESPACE"`
export configmap=`get_octopusvariable "__STACK"`
export context=`get_octopusvariable "__CONTEXT"`
export multiClusterDeployment=`get_octopusvariable "__MULTICLUSTERDEPLOYMENT"`

check_configmap() {
	check_configmap_md5=`kubectl --context=$context get configmap "$1" --namespace $namespace --output json | jq .data | md5sum`
	write_verbose "$1 md5 output: $check_configmap_md5"
}

delete_configmap() {
	write_verbose "Deleting old configmap: $1"
	kubectl --context=$context delete configmap "$1" --namespace $namespace
}

check_cm_before() {
	write_verbose "check existance of configmap $1"
	kubectl --context=$context get configmap "$1" --namespace $namespace &>/dev/null
	if [ "$?" = "0" ]; then
			write_verbose "Configmap $1 exists, creating md5 for comparisson"
			check_configmap "$1"
			delete_configmap "$1"
			before="$check_configmap_md5"
	fi
}

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

# Get an md5 of the existing config map
# Then delete it, as they can't be upgraded
check_cm_before "$configmap-config"
before="$check_configmap_md5"
check_cm_before "global-$configmap-config"
global_before="$check_configmap_md5"

# Add the new config maps for local and global variables
create_configmap "$configmap-config" "$PackageRoot/environments/$envDir/$configmap.env"
create_configmap "global-$configmap-config" "$PackageRoot/environments/common.env"

# Get the md5 after the new version is applied
check_configmap "$configmap-config"
after="$check_configmap_md5"
check_configmap "global-$configmap-config"
global_after="$check_configmap_md5"

# Set the variable to roll the pods, if a CM has changed.
if [ "$before" == "$after" ] && [ "$global_before" == "$global_after" ] ; then
    write_verbose "Configmap has not changed."
    write_verbose "Pods will not be removed."
	set_octopusvariable "ConfigrationMapsChanged" "false"
else
    write_highlight "The Configmap(s) has changed"
    write_highlight "Old pods will be removed after deployment"
    set_octopusvariable "ConfigrationMapsChanged" "true"
fi
 