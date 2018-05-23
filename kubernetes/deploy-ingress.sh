#!/bin/bash

release_number=$(get_octopusvariable "Octopus.Release.Number")
namespace=$(get_octopusvariable "__NAMESPACE")
stack=$(get_octopusvariable "__STACK")
context=$(get_octopusvariable "__CONTEXT")
ingressType=$(get_octopusvariable "__INGRESSTYPE")
multiClusterDeployment=$(get_octopusvariable "__MULTICLUSTERDEPLO)MENT"`


PackageRoot=$HOME/.octopus/OctopusServer/Work/tools/$release_number/$namespace
echo "Using PackageTransferPath: $PackageRoot"

#Invoke Kubernetes CLI for this particular environment

# If the ingress is a multi cluster deployment
if [ "$multiClusterDeployment" == "true" ]; then
    envDir="$namespace/$context"
else #Otherwise, do the standard single cluster deployment
    envDir="$namespace"
fi

echo "Running Kubectl CLI compose for $envDir with following properties:"
cat $PackageRoot/environments/$envDir/k8s-infrastructure.yaml
echo

echo "Render Config for $stack stack, ingress type $ingressType"
kubetpl render $PackageRoot/k8s/$stack/$stack-$ingressType.yaml.kubetpl-go -i $PackageRoot/environments/$envDir/k8s-infrastructure.yaml | cat -

echo "Apply Config for $stack stack, ingress type $ingressType"
kubetpl render $PackageRoot/k8s/$stack/$stack-$ingressType.yaml.kubetpl-go -i $PackageRoot/environments/$envDir/k8s-infrastructure.yaml | kubectl --context=$context apply -f -

