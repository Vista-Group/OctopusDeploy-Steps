#!/bin/bash

namespace=$(get_octopusvariable "__NAMESPACE")
stack=$(get_octopusvariable "__STACK")
context=$(get_octopusvariable "__CONTEXT")
multiClusterDeployment=$(get_octopusvariable "__MULTICLUSTERDEPLOYMENT")

deployer=$(get_octopusvariable "Octopus.Deployment.CreatedBy.DisplayName")
deployment_date=$(get_octopusvariable "Octopus.Deployment.Created")
deployment_id=$(get_octopusvariable "Octopus.Deployment.Id")
deployment_name=$(get_octopusvariable "Octopus.Deployment.Name")
release_id=$(get_octopusvariable "Octopus.Release.Id")
release_number=$(get_octopusvariable "Octopus.Release.Number")

# Get the configuration (docker compose and environ overrides) from the OctoPackage 'gtp_config'
# Resolve docker templates for a particular stack from manifest
PackageRoot=$HOME/.octopus/OctopusServer/Work/tools/$release_number/$namespace
echo "Using PackageTransferPath: $PackageRoot"

# If the ingress is a multi cluster deployment
# for example: ../ci/.. vs ../production/mx-test/..
echo "The deployment has particular config for each cluster: $multiClusterDeployment"
if [ "$multiClusterDeployment" == "true" ] || [ "$multiClusterDeployment" == "True" ] ; then
    envDir="$namespace/$context"
    echo "Using multiClusterDeployment: $envDir"
else #Otherwise, do the standard single cluster deployment
    envDir="$namespace"
    echo "Using standard single cluster deployment: $envDir"
fi

infraVariables=$PackageRoot/environments/$envDir/k8s-infrastructure.yaml
echo "Using ifraVariables file: $infraVariables"

echo "vista_deployer: $deployer" >> $infraVariables
echo "vista_deployment_date: $deployment_date" >> $infraVariables
echo "vista_deployment_id: $deployment_id" >> $infraVariables
echo "vista_deployment_name: $deployment_name" >> $infraVariables
echo "vista_release_id: $release_id" >> $infraVariables
echo "vista_release_number: $release_number" >> $infraVariables

echo "namespace=$namespace" > $namespace.env
echo >> $namespace.env

#Avoid the warning from no matching files
shopt -u nullglob
filecount=$(find $PackageRoot -maxdepth 1 -type f -name '*.env' | wc -l)
echo "Number of files in the directory: $filecount"
if [ $filecount \> 0 ]; then
        for FILE in $PackageRoot/*.env; do
            echo "Processing env filename $FILE"
            #hack to remove the export keywork as we don't use config from env anymore
            cat $FILE | awk  '{ print $2 }' >> $namespace.env
            echo >> $namespace.env
        done
else
        echo "No env files to process"
fi

#Invoke Kubernetes CLI for this particular environment
echo
echo "Running Kubectl CLI compose for $namespace with following properties file content:"
cat $namespace.env
echo "Running Kubectl CLI compose with following infrastructure settings file content:"
cat $infraVariables

KeyValuePairs=$(get_octopusvariable "__KEY_VALUE_PAIRS")
echo "Extra Config KeyValuePairs $KeyValuePairs"

ConfigurationFilename=$(get_octopusvariable "__CONFIGURATION_FILENAME")
echo "Render Config $ConfigurationFilename for stack $stack"
kubetpl render $PackageRoot/k8s/$stack/$ConfigurationFilename -i $namespace.env -i $infraVariables -s $KeyValuePairs | cat -

echo "Apply Config $ConfigurationFilename for stack $stack"
kubetpl render $PackageRoot/k8s/$stack/$ConfigurationFilename -i $namespace.env -i $infraVariables -s $KeyValuePairs | kubectl --context=$context apply -f -
