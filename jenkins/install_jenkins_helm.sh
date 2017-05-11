#!/bin/bash
kubectl create -f jenkins-claim.yaml
helm install --name jenkins  --set Master.ServiceType=NodePort --set Persistence.ExistingClaim=jenkins-claim stable/jenkins
kubectl create -f jenkins-ingress.yaml