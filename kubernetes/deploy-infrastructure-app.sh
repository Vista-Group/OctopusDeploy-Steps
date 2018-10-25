#!/bin/bash

namespace=$(get_octopusvariable "__NAMESPACE")
stack=$(get_octopusvariable "__STACK")
app=$(get_octopusvariable "__APP")
context=$(get_octopusvariable "__CONTEXT")
configmap=$(get_octopusvariable "__CONFIGMAP")
configmapDirectory=$(get_octopusvariable "__CONFIGMAPDIRECTORY")
multiClusterDeployment=$(get_octopusvariable "__MULTICLUSTERDEPLOYMENT")
deployer=$(get_octopusvariable "Octopus.Deployment.CreatedBy.DisplayName")
deployment_date=$(get_octopusvariable "Octopus.Deployment.Created")
deployment_id=$(get_octopusvariable "Octopus.Deployment.Id")
deployment_name=$(get_octopusvariable "Octopus.Deployment.Name")
release_id=$(get_octopusvariable "Octopus.Release.Id")
release_number=$(get_octopusvariable "Octopus.Release.Number")

PackageRoot=$HOME/.octopus/OctopusServer/Work/tools/$release_number/$namespace
echo "Using PackageTransferPath: $PackageRoot"

# If the ingress is a multi cluster deployment
if [ "$multiClusterDeployment" == "true" ]; then
    echo "This is a multi cluster deployment."
    envDir="$namespace/$context"
else #Otherwise, do the standard single cluster deployment
    echo "This is a single cluster deployment."
    envDir="$namespace"
fi

#If $configmapDirectory is not empty
if [ ! -z $configmapDirectory ]; then
    echo "Configmap of a directory is required"

    echo "Removing configmap $stack-$app-configmap-dir"
    echo "Because we can't use 'kubectl apply cm' :'("
    kubectl --context=$context delete configmap "$stack-$app-configmap-dir" --namespace $namespace

    echo "Creating configmap of directory: $configmapDirectory"
    kubectl --context=$context create configmap "$stack-$app-configmap-dir" --namespace $namespace --from-file=$PackageRoot/$configmapDirectory
else
    echo "Configmap of a directory is not required."
fi

infraVariables=$PackageRoot/environments/$envDir/k8s-infrastructure.yaml
echo "Using ifraVariables file: $infraVariables"

echo "vista_deployer: $deployer" >> $infraVariables
echo "vista_deployment_date: $deployment_date" >> $infraVariables
echo "vista_deployment_id: $deployment_id" >> $infraVariables
echo "vista_deployment_name: $deployment_name" >> $infraVariables
echo "vista_release_id: $release_id" >> $infraVariables
echo "vista_release_number: $release_number" >> $infraVariables

# Support arbitrary KV pairs from Octopus, such as traefik secret variables
KeyValuePairs=$(get_octopusvariable "__KEY_VALUE_PAIRS")
echo "Extra Config KeyValuePairs $KeyValuePairs"

kubetpl render $PackageRoot/k8s/$stack/$app.yaml -i $infraVariables -s $KeyValuePairs > $app-$stack-$context.yaml

# new_octopusartifact $app-$stack-$context.yaml $app-$stack-$context.yaml

echo "Apply manifest for $stack stack"
kubectl --context=$context apply -f $app-$stack-$context.yaml

# If rendering|applying the manifest fails, fail the step
if [ "$?" = "1" ]; then
    fail_step "Looks like the manifest failed to apply. Check logs to find out why!"
fi
