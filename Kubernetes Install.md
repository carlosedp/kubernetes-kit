# Kubernetes Install/Config

## Building a multi-platform Kubernetes cluster with kubeadm

* Create 3 CentOS 1611 machines (1 master, 2 nodes)
* Install using ansible playbook from [https://github.com/ReSearchITEng/kubeadm-playbook](https://github.com/ReSearchITEng/kubeadm-playbook)
* Add hosts to `hosts` file
* Configure group_vars:

    # global variables
    # proxy environment variable, mainly for fetching addons
    proxy_env:
      http_proxy: ""
      https_proxy: ""
      no_proxy: ""

    # first uninstall any kube* package from all hosts
    full_kube_reinstall: False

    # Desired state for the yum packages (docker, kube*); it defaults to latest, trying to upgrade every time.
    package_state: latest # Other valid options for this context: present

    # Desired kubernetes_version, e.g. 'v1.6.1'  ; when not defined, defaults to: 'latest'
    kubernetes_version: v1.6.2

    # Any kubeadm init extra params can be put here. The var must exist, even if it's empty.
    # e.g. for using flannel, one must put: --pod-network-cidr='10.244.0.0/16'
    #kubeadm_init_extra_params: "--pod-network-cidr='10.244.0.0/16'"
    kubeadm_init_extra_params: ""

    # service_dns_domain: "myk8s.corp.example.com" # (cluster.local is the default, if not defined)
    service_dns_domain: "kube.local"

    apiserver_cert_extra_sans: api.kube.local,10.178.11.236,kube.local

    # kube-apiserver_extra_params
    # Values are here: https://kubernetes.io/docs/admin/kube-apiserver/
    # ansible will update them on the master, here: /etc/kubernetes/manifests/kube-apiserver.yaml, after the "- kube-apiserver" line
    # Note the spaces in front, as it must match with the /etc/kubernetes/manifests/kube-apiserver.yaml
    kube_apiserver_extra_params:
      - '    - --service-node-port-range=79-32767' #Default 32000-32767

    #If you want to be able to schedule pods on the master
    #It's useful if it's a single-machine Kubernetes cluster for development (replacing minikube), set it to true
    use_master_as_node_also: true

    ### Network addons. More details: https://kubernetes.io/docs/admin/addons/
    # Calico:
    #kubeadm_network_addons_urls:
    #  - http://docs.projectcalico.org/v2.1/getting-started/kubernetes/installation/hosted/kubeadm/1.6/calico.yaml

    # Weave
    kubeadm_network_addons_urls:
       - https://git.io/weave-kube-1.6

    # Flannel:
    #kubeadm_network_addons_urls:
    #  - https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel-rbac.yml
    #  - https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

    helm:
      install_script_url: 'https://github.com/kubernetes/helm/raw/master/scripts/get'
      repos:
        - { name: fabric8, url: 'https://fabric8.io/helm' }
      packages_list: #when not defined, namespace defaults to "default" namespace
    #    - { name: nginx-ingress, repo: stable/nginx-ingress, namespace: kube-system, options: '--set controller.stats.enabled=true --set controller.service.type=NodePort --set controller.service.nodePorts.http=80 --set controller.service.nodePorts.https=443' }
    #    - { name: prometheus, repo: stable/prometheus, namespace: kube-system, options: '' }

    # kubeadm_docker_insecure_registry: registry.example.com:5000

    # Static token (generated on the fly if not set). Alphanum strings with lengths: 6.16
    # kubeadm_token: secret.token4yourbyok8s

    # shell for bash-completion for kubeadm and kubectl; currently only bash is fully supported, others only partially.
    shell: 'bash'


* Taint the master node
    `kubectl taint nodes --all node-role.kubernetes.io/master-`
* Deploy Kubernetes Dashboard, Dashboard ingress
* Deploy Heapster
* Deploy Ingress Controller Traefik and Traefik-ui
* Create LoadBalancer for the Traefik Ingress (Input on floatingIP port 80. Out to all nodes port 30080)
* Deploy Rook
    kubectl apply -f https://raw.githubusercontent.com/rook/rook/master/demo/kubernetes/rook-operator.yaml
    kubectl apply -f https://raw.githubusercontent.com/rook/rook/master/demo/kubernetes/rook-cluster.yaml
    kubectl apply -f https://raw.githubusercontent.com/rook/rook/master/demo/kubernetes/rook-storageclass.yaml
    # Repeat this step for all namespaces you want to deploy PersistentVolumes with Rook in
    kubectl get secret rook-rook-user -oyaml | sed "/resourceVer/d;/uid/d;/self/d;/creat/d;/namespace/d" | kubectl -n kube-system apply -f -
    # In order to make Rook the default Storage Provider by making the `rook-block` Storage Class the default, run this:
    kubectl patch storageclass rook-block -p '{"metadata":{"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}'

* Deploy InfluxDB and Grafana
* Install Helm
* Deploy Service Catalog

### References:
* [https://github.com/luxas/kubeadm-workshop](https://github.com/luxas/kubeadm-workshop)

----------------------------------------------------------------------------------------

## Kubernetes log
klog() {
    POD=$1
    INPUT_INDEX=$2
    INDEX="${INPUT_INDEX:-1}"
    PODS=`kubectl get pods --all-namespaces|grep ${POD} |head -${INDEX} |tail -1`
    PODNAME=`echo ${PODS} |awk '{print $2}'`
    echo "Pod: ${PODNAME}"
    echo
    NS=`echo ${PODS} |awk '{print $1}'`
    kubectl logs -f --namespace=${NS} ${PODNAME}
}

## Kubernetes Pods commands

alias wpods='watch kubectl get pods --all-namespaces'
alias ksvc='kubectl get services --all-namespaces'
alias kpod='kubectl get pods --all-namespaces'
alias kedp='kubectl get endpoints --all-namespaces'

## Kubernetes install Weavescope

Install nsenter and socat on all nodes:
     sudo apt-get install socat
     sudo docker run -v /usr/local/bin:/target jpetazzo/nsenter

     wget https://cloud.weave.works/launch/k8s/weavescope.yaml

**Change port mapping from 80 to 4040**

kubectl apply -f weavescope.yaml

## Enable Openstack Load Balancer integration

    * Enable LBAAS v2 on Openstack
    * Configure kube-apiserver and kube-controller-manager to load openstack integration

Add to `/etc/kubernetes/manifests/kube-apiserver.yaml` on master node

    - --cloud-provider=openstack
    - --cloud-config=/etc/kubernetes/openstack.conf


Add to `/etc/kubernetes/manifests/kube-controller-manager.yaml` on master node

    - --cloud-provider=openstack
    - --cloud-config=/etc/kubernetes/openstack.conf

Create /etc/kubernetes/openstack.conf

    [Global]
    auth-url=http://10.178.11.224:5000/v2.0
    username=admin
    password=admin
    tenant-name=admin
    region=RegionOne
    [LoadBalancer]
    lb-version=v2
    subnet-id=19740287-edc5-4f86-a4a5-5cae6743d3a2
    floating-network-id=6d3a33cc-8c7b-4929-a1a9-ae0e1206bd1c
    [Route]
    router-id=353f74ce-68b5-40db-b1a5-1793fe3be839

### Example APP with loadbalancer:

Create nginx.yaml:

    apiVersion: v1
    kind: Pod
    metadata:
      name: nginx
      labels:
       app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80

Create nginx-svc.yaml:

    apiVersion: v1
    kind: Service
    metadata:
      name: nginxservice
      labels:
        app: nginx
    spec:
      ports:
      - port: 80 88
        targetPort: 80
        protocol: TCP
      selector:
        app: nginx
      type: LoadBalancer

Load services:

     kubectl create -f nginx.yaml
     kubectl create -f nginx-svc.yaml

## Allow scheduling on master
    kubectl taint nodes --all node-role.kubernetes.io/master-

## Fix permission for RBAC (Not to be used)
    kubectl create clusterrolebinding add-on-cluster-account --clusterrole=cluster-admin --serviceaccount=default:default

