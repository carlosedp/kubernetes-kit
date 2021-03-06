#!/bin/bash
helm install --name gitlab --set image=gitlab/gitlab-ce:9.1.3-ce.0 --set serviceType=NodePort --set externalUrl=http://gitlab.kube.com stable/gitlab-ce

kubectl create -f gitlab-ingress.yaml
