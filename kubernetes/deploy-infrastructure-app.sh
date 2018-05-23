#!/bin/bash

export releaseNumber=`get_octopusvariable "Octopus.Release.Number"`
export namespace=`get_octopusvariable "__NAMESPACE"`
export stack=`get_octopusvariable "__STACK"`
export app=`get_octopusvariable "__APP"`
export context=`get_octopusvariable "__CONTEXT"`
export configmap=`get_octopusvariable "__CONFIGMAP"`
export configmapDirectory=`get_octopusvariable "__CONFIGMAPDIRECTORY"`
export multiClusterDeployment=`get_octopusvariable "__MULTICLUSTERDEPLOYMENT"`
export mx_deployment_id=`get_octopusvariable "Octopus.Deployment.Id"`
export mx_deployment_date=`get_octopusvariable "Octopus.Deployment.Created"`
export mx_deployer=`get_octopusvariable "Octopus.Deployment.CreatedBy.DisplayName"`
export mx_deployment_name=`get_octopusvariable "Octopus.Deployment.Name"`
export mx_release_id=`get_octopusvariable "Octopus.Release.Id"`

check_configmap() {
    if [ -z $1 ]; then
        echo "No configmap specified for $app."
        echo "Skipping configmap checks."
        return
    fi

	echo "check existance of configmap $1"
    kubectl --context=$context get configmap "$1" --namespace $namespace &>/dev/null
    if [ "$?" = "0" ]; then
        echo "Configmap $1 exists, creating md5 for comparisson"
        check_configmap_md5=`kubectl --context=$context get configmap "$1" --namespace $namespace --output json | jq .data | md5sum`
        echo "$1 md5 output: $check_configmap_md5"
    fi
}

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

check_configmap "$configmap"
before="$check_configmap_md5"

#If $configmapDirectory is not empty
if [ ! -z $configmapDirectory ]; then
    echo "Configmap of a directory is required"

    # get an md5 of the config before updating
    check_configmap "$stack-$app-configmap-dir"
    beforeDir="$check_configmap_md5"

    echo "Removing configmap $stack-$app-configmap-dir"
    echo "Because we can't use 'kubectl apply cm' :'("
    kubectl --context=$context delete configmap "$stack-$app-configmap-dir" --namespace $namespace

    echo "Creating configmap of directory: $configmapDirectory"
    kubectl --context=$context create configmap "$stack-$app-configmap-dir" --namespace $namespace --from-file=$PackageRoot/$configmapDirectory
    

    # get an md5 of the config after updating
    check_configmap "$stack-$app-configmap-dir"
    afterDir="$check_configmap_md5" 
else
    echo "Configmap of a directory is not required."
fi

#Invoke Kubernetes CLI for this particular environment
### Requires an octopus upgrade to support these functions
write_verbose "Running Kubectl CLI compose for $envDir with following properties:"
write_verbose `cat $PackageRoot/environments/$envDir/k8s-infrastructure.yaml`

write_verbose  `kubetpl render $PackageRoot/k8s/$stack/$app.yaml \
                -i $PackageRoot/environments/$envDir/k8s-infrastructure.yaml \
                -s mx_deployment_id=$mx_deployment_id \
                -s mx_deployment_datae=$mx_deployment_date \
                -s mx_deployer=$mx_deployer \
                -s mx_deployment_name=$mx_deployment_name \
                -s mx_release_number=$releaseNumber \
                -s mx_release_id=$mx_release_id \
                | kubectl --context=$context apply -f -`

echo "Apply manifest for $stack stack"
kubetpl render $PackageRoot/k8s/$stack/$app.yaml \
    -G -i $PackageRoot/environments/$envDir/k8s-infrastructure.yaml \
    -s mx_deployment_id=$mx_deployment_id \
    -s mx_deployment_datae=$mx_deployment_date \
    -s mx_deployer=$mx_deployer \
    -s mx_deployment_name=$mx_deployment_name \
    -s mx_release_number=$releaseNumber \
    -s mx_release_id=$mx_release_id \
    | kubectl --context=$context apply -f -

# If rendering|applying the manifest fails, fail the step
if [ "$?" = "1" ]; then
    fail_step "Looks like the manifest failed to apply. Check logs to find out why!"
fi

# Force the pods to regenerate if there was a configmap change.
check_configmap "$configmap"
after="$check_configmap_md5"

if [ "$before" == "$after" ] && [ "$beforeDir" == "$afterDir" ] ; then
    write_verbose "Configmap has not changed."
    write_verbose "Pods will not be removed."
elif [ -z "$before" ]
then
    write_verbose "There was no previous config map."
    write_verbose "Pods do not need to be refreshed."
else
    write_highlight "The Configmap has changed"
    write_highlight "Removing old pods..."
    kubectl --context=$context delete pods -l stack=$stack,app=$app --namespace $namespace
fi