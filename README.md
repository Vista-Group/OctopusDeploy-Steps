# Octopus Deploy Step Templates

Repository for automation of step templates that perform common tasks 
for deployment on our container schedulers, with Octopus Deploy.


## Kubernetes

- configmap.sh create or replace a configmap
- apply.sh render a config and kubectl apply it
- deploy-infrastructure-app.sh : deploy prometheus/traefik/etcetera
- deploy-ingress.sh : deploy an ingress
- deploy.sh : create or replace a deployment
- set-namespace.sh : select the kube configuration
- wait-till-ready.sh : waits for readines state on containers


## Rancher

- coming soon
