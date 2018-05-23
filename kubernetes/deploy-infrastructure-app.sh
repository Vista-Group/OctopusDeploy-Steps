#!/bin/bash

export releaseNumber=`get_octopusvariable "Octopus.Release.Number"`
export namespace=`get_octopusvariable "__NAMESPACE"`
export stack=`get_octopusvariable "__STACK"`
export app=`get_octopusvariable "__APP"`
export context=`get_octopusvariable "__CONTEXT"`
export configmap=`get_octopusvariable "__CONFIGMAP"`
export configmapDirectory=`get_octopusvariable "__CONFIGMAPDIRECTORY"`
export multiClusterDeployment=`get_octopusvariable "__MULTICLUSTERDEPLOYMENT"`

PackageRoot=$HOME/.octopus/OctopusServer/Work/tools/$releaseNumber/$namespace
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

echo "deployer: $(get_octopusvariable \"Octopus.Deployment.CreatedBy.DisplayName\")" >> $infraVariables
echo "deployment_date: $(get_octopusvariable \"Octopus.Deployment.Created\")" >> $infraVariables
echo "deployment_id: $(get_octopusvariable \"Octopus.Deployment.Id\")" >> $infraVariables
echo "deployment_name: $(get_octopusvariable \"Octopus.Deployment.Name\")" >> $infraVariables
echo "release_id: $(get_octopusvariable \"Octopus.Release.Id\")" >> $infraVariables
echo "release_number: $(get_octopusvariable \"Octopus.Release.Number\")" >> $infraVariables

#Invoke Kubernetes CLI for this particular environment
### Requires an octopus upgrade to support these functions
echo  "Running kubectl for $envDir with following properties:"
cat $infraVariables

echo "Apply manifest for $stack stack"
kubetpl render $PackageRoot/k8s/$stack/$app.yaml -i $infraVariables | kubectl --context=$context apply -f -

# If rendering|applying the manifest fails, fail the step
if [ "$?" = "1" ]; then
    fail_step "Looks like the manifest failed to apply. Check logs to find out why!"
fi
