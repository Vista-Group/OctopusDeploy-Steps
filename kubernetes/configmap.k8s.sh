export releaseNumber=`get_octopusvariable "Octopus.Release.Number"`
export namespace=`get_octopusvariable "__NAMESPACE"`
export configmap=`get_octopusvariable "__STACK"`
export context=`get_octopusvariable "__CONTEXT"`
export multiClusterDeployment=`get_octopusvariable "__MULTICLUSTERDEPLOYMENT"`

# Get the configuration (docker compose and environ overrides) from the OctoPackage 'gtp_config'
# Resolve docker templates for a particular stack from manifest
PackageRoot=$HOME/.octopus/OctopusServer/Work/tools/$releaseNumber/$namespace
echo "Using PackageTransferPath: $PackageRoot"

# If the ingress is a multi cluster deployment
if [ "$multiClusterDeployment" == "true" ]; then
    envDir="$namespace/$context"
else #Otherwise, do the standard single cluster deployment
    envDir="$namespace"
fi

#TODO check for changes with md5sum or something
echo "check existance of configmap $configmap-config"
kubectl --context=$context get configmap "$configmap-config" --namespace $namespace &>/dev/null
if [ "$?" = "0" ]; then
		#create a md5sum of it 
        before=`kubectl --context=$context get configmap "$configmap-config" --namespace $namespace --output json | jq .data | md5sum`
		echo "$configmap md5 before deployment: $before"

		echo "Deleting old configmap"
		kubectl --context=$context delete configmap "$configmap-config" --namespace $namespace
fi

# create
echo "create configmap $configmap-config in namespace $namespace "
kubectl --context=$context create configmap "$configmap-config" --namespace $namespace --from-env-file=$PackageRoot/environments/$envDir/$configmap.env

after=`kubectl --context=$context get configmap "$configmap-config" --namespace $namespace --output json | jq .data | md5sum`
echo "$configmap md5 after deployment: $after"

if [ "$before" == "$after" ]; then
	set_octopusvariable "ConfigrationMapsChanged" "false"
	echo "Configmap has not changed."
elif [ -z "$before" ]; then
	set_octopusvariable "ConfigrationMapsChanged" "false"
	echo "First deployment of this Configmap. No change."
else
	set_octopusvariable "ConfigrationMapsChanged" "true"
	echo "Configmap has changed."
fi