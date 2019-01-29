#!/bin/bash

release_number=$(get_octopusvariable "Octopus.Release.Number")
namespace=$(get_octopusvariable "__NAMESPACE")
stack=$(get_octopusvariable "__STACK")
context=$(get_octopusvariable "__CONTEXT")

# Get the configuration (docker compose and environ overrides) from the OctoPackage 'gtp_config'
# Resolve docker templates for a particular stack from manifest
PackageRoot=$HOME/.octopus/OctopusServer/Work/tools/$release_number/$namespace
echo "Using PackageTransferPath: $PackageRoot"

echo "Wait for pods to be ready"

for i in {1..20}
do
	kubectl --context=$context get pods -l stack=$stack --namespace=$namespace -o json  | jq -r '.items[] | select(.status.phase != "Running" or ([ .status.conditions[] | select(.type == "Ready" and .status == "False") ] | length ) == 1 ) | .metadata.namespace + "/" + .metadata.name'
  	OUTPUT="$(kubectl --context=$context get pods -l stack=$stack --namespace=$namespace -o json  | jq -r '.items[] | select(.status.phase != "Running" or ([ .status.conditions[] | select(.type == "Ready" and .status == "False") ] | length ) == 1 ) | .metadata.namespace + "/" + .metadata.name' | wc -l)"
	
	write_wait "Containers not in running state: ${OUTPUT}"
    
    #if all the containers are running exit the step
    if [ "$OUTPUT" = "0" ]; then
    	exit 0
	fi
    
  	sleep 15s
done

exit 1
