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

ConfigurationFilename=$(get_octopusvariable "__CONFIGURATION_FILENAME")
echo "Render Kubernetes Config $ConfigurationFilename for stack $stack"

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

#Hack for the egress stack (inspects the load balancer ip with azureRM)
KeyValuePairs=$(get_octopusvariable "__KEY_VALUE_PAIRS")
echo "Extra Config KeyValuePairs $KeyValuePairs"

#Create the metadata with the image tag version
echo "namespace=$namespace" > $namespace.env
echo >> $namespace.env

#Avoid the warning from no matching files
shopt -u nullglob
find $PackageRoot -maxdepth 1 -type f -name '*.env'
filecount=$(find $PackageRoot -maxdepth 1 -type f -name '*.env' | wc -l)
echo "Number of files in the directory: $filecount"
if [ $filecount == '0' ]; then
	echo "No env files to process"
else
  for FILE in $PackageRoot/*.env; do
    echo "Processing env filename $FILE"
    #hack to remove the export keywork as we don't use config from env anymore
    cat $FILE | awk  '{ print $2 }' >> $namespace.env
    echo >> $namespace.env
  done
fi


#Invoke Kubernetes CLI for this particular environment
echo "Adding deployment metadata to infrastructure settings file"
echo "vista_deployer: $deployer" >> $namespace.env
echo "vista_deployment_date: $deployment_date" >> $namespace.env
echo "vista_deployment_id: $deployment_id" >> $namespace.env
echo "vista_deployment_name: $deployment_name" >> $namespace.env
echo "vista_release_id: $release_id" >> $namespace.env
echo "vista_release_number: $release_number" >> $namespace.env

echo "Running Kubectl CLI compose for $namespace with image and deployment metadata content:"
cat $namespace.env

#Render using infraVariables only if available
infraVariables=$PackageRoot/environments/$envDir/k8s-infrastructure.yaml
echo "Using ifraVariables file: $infraVariables (if available)"

if [ ! -f $infraVariables ]; then
    echo "Running Kubectl CLI compose without infrastructure settings file available!"
	kubetpl render $PackageRoot/k8s/$stack/$ConfigurationFilename --debug -i $namespace.env -s $KeyValuePairs > $PackageRoot/rendered-$namespace-$stack-deployment.yaml    
else
	echo "Running Kubectl CLI compose with following infrastructure settings file content:"
	cat $infraVariables

	kubetpl render $PackageRoot/k8s/$stack/$ConfigurationFilename --debug -i $namespace.env -i $infraVariables -s $KeyValuePairs > $PackageRoot/rendered-$namespace-$stack-deployment.yaml
fi

#publish the rendered deployment as an artifact path and name
echo "Publish (print) Config $ConfigurationFilename for stack $stack"
cat $PackageRoot/rendered-$namespace-$stack-deployment.yaml

echo "Apply Config $ConfigurationFilename for stack $stack"
kubectl --context=$context apply -f $PackageRoot/rendered-$namespace-$stack-deployment.yaml
