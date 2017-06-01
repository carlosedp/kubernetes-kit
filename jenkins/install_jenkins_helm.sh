#!/bin/bash
kubectl create -f jenkins-claim.yaml

kubectl -n default create sa jenkins
kubectl create clusterrolebinding jenkins --clusterrole cluster-admin --serviceaccount=default:jenkins

helm install --name jenkins  --set Master.ServiceType=LoadBalancer --set Persistence.ExistingClaim=jenkins-claim --set Master.ImageTag="2.61" --set Master.ServicePort=80 stable/jenkins

kubectl create -f jenkins-ingress.yaml

# Install / Configure Gitlab plugins
#  * Create a Jenkins user on Gitlab.
#  * On "Gitlab", "Gitlab Account", "Gitlab Notifier" and "Gitlab Merge Request Builder" sections, add URL and the user API token.
# Configure Jenkins Kubernetes plugin to cluster access:
#  * Add URL from Kube API
#  * Add CA.crt from /etc/kubernetes/pki/ca.crt to Kubernetes server certificate key
#  * Add namespace default
#  * Add a Kubernetes Service Account jenkins
#  * Add Jenkins URL
#  * In Tunnel, add the IP of the loadbalancer:50000 or the hostname associated to it.
