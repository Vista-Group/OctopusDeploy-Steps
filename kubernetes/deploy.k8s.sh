export releaseNumber=`get_octopusvariable "Octopus.Release.Number"`
export namespace=`get_octopusvariable "__NAMESPACE"`
export replicas=`get_octopusvariable "__REPLICAS"`
export stack=`get_octopusvariable "__STACK"`
export context=`get_octopusvariable "__CONTEXT"`
export multiClusterDeployment=`get_octopusvariable "__MULTICLUSTERDEPLOYMENT"`

# Get the configuration (docker compose and environ overrides) from the OctoPackage 'gtp_config'
# Resolve docker templates for a particular stack from manifest
PackageRoot=$HOME/.octopus/OctopusServer/Work/tools/$releaseNumber/$namespace
echo "Using PackageTransferPath: $PackageRoot"

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


# If the ingress is a multi cluster deployment
if [ "$multiClusterDeployment" == "true" ]; then
    envDir="$namespace/$context"
else #Otherwise, do the standard single cluster deployment
    envDir="$namespace"
fi

echo "Render Config for $stack stack"
kubetpl render $PackageRoot/k8s/$stack/$stack-stack.yaml.kubetpl-go -G -i $namespace.env -s NAMESPACE=$namespace -s REPLICAS=$replicas | cat -

echo "Apply Config for $stack stack"
kubetpl render $PackageRoot/k8s/$stack/$stack-stack.yaml.kubetpl-go -G -i $namespace.env -s NAMESPACE=$namespace -s REPLICAS=$replicas | kubectl --context=$context apply -f -

echo "Restart the pods if the previous step signaled a config change"
ConfigrationMapsChanged=$(get_octopusvariable "Octopus.Action[Kubernetes ConfigMap].Output.ConfigrationMapsChanged")
echo "ConfigrationMapsChanged: $ConfigrationMapsChanged"

if [ "$ConfigrationMapsChanged" == "true" ]; then
	echo "ConfigMap has changed."
    echo "remove old pods"
    kubectl --context=$context delete pods -l stack=$stack --namespace $namespace
fi
