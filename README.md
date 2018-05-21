# Octopus Deploy Step Templates

Repository for automation of step templates that perform common tasks 
for deployment on our container schedulers


## Kubernetes

- configmap.k8s.sh create or replace a configmap
- deploy-infrastructure-app.k8s.sh : deploy prometheus
- deploy-ingress.k8s.sh : deploy an ingress
- deploy.k8s.sh : create or replace a deployment
- set-namespace.k8s.sh : select the kube configuration
- wait-till-ready.k8s.sh : waits for readines state on containers


## Rancher

- coming soon