#!/bin/bash

namespace=$(get_octopusvariable "__NAMESPACE")
replicas=$(get_octopusvariable "__REPLICAS")
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
if [ "$multiClusterDeployment" == "true" ]; then
    envDir="$namespace/$context"
else #Otherwise, do the standard single cluster deployment
    envDir="$namespace"
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
for FILE in $PackageRoot/*.env; do
	shopt -u nullglob
	echo "Filename $FILE"
    cat $FILE
    echo
    #hack to remove the export keywork as we don't use config from env anymore
    cat $FILE | awk  '{ print $2 }' >> $namespace.env
    echo >> $namespace.env
done

#Invoke Kubernetes CLI for this particular environment
echo
echo "Running Kubectl CLI compose for $namespace with following properties:"
cat $namespace.env
cat $infraVariables

echo "Render Config for $stack stack"
# $namespace.env contains the versions of the app to be deployed.
# k8s-infrastructure.yaml contains variabls for the infrastructure. e.g. namespace, replicas
kubetpl render $PackageRoot/k8s/$stack/$stack-stack.yaml.kubetpl-go -i $namespace.env -i $infraVariables | cat -

echo "Apply Config for $stack stack"
kubetpl render $PackageRoot/k8s/$stack/$stack-stack.yaml.kubetpl-go -i $namespace.env -i $infraVariables | kubectl --context=$context apply -f -
