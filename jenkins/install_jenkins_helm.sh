#!/bin/bash
kubectl create -f jenkins-claim.yaml
helm install --name jenkins  --set Master.ServiceType=LoadBalancer --set Persistence.ExistingClaim=jenkins-claim --set Master.ImageTag="2.61" stable/jenkins
kubectl create -f jenkins-ingress.yaml
