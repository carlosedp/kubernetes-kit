# Kubernetes Install/Config

## Building a multi-platform Kubernetes cluster with kubeadm

### Install Kubernetes

* Create 3 CentOS 1611 machines (1 master, 2 nodes)
* Install using ansible playbook from [https://github.com/ReSearchITEng/kubeadm-playbook](https://github.com/ReSearchITEng/kubeadm-playbook)
* Add hosts to `hosts` file
* Configure group_vars:
    - Disable rook
    - Disable Helm (Fails because lacks RBAC permissions. Need redeployment)
    ```
    full_kube_reinstall: False
    package_state: installed
    kubernetes_version: 'v1.6.4'
    kubeadm_init_extra_params: "--pod-network-cidr='10.244.0.0/16'"
    service_dns_domain: "kube.com"
    apiserver_cert_extra_sans: api.kube.com,10.178.11.236,kube.com,master-1
    kube_apiserver_extra_params:
      - '    - --service-node-port-range=79-32767' #Default 32000-32767
    use_master_as_node_also: true
    master_uncordon: True     # This makes master like any other node. Mandatory for a single machine cluster (where master==node)

    k8s_network_addons_urls:
       + https://git.io/weave-kube-1.6

    k8s_addons_urls:
      + https://github.com/kubernetes/dashboard/raw/master/src/deploy/kubernetes-dashboard.yaml
    helm:
      install_script_url: 'https://github.com/kubernetes/helm/raw/master/scripts/get'
      repos:
        - { name: fabric8, url: 'https://fabric8.io/helm' }
    kubeadm_token: secret.token4yourbyok8s
    shell: 'bash'
    ```

* Taint the master node (If not done in the playbook)
    `kubectl taint nodes --all node-role.kubernetes.io/master-`
    `kubectl taint nodes --all dedicated-`

### Install addons

* Deploy Traefik Ingress Controller and Traefik-ui from traefik dir
* Deploy keepalived-vip from keepalived-vip dir. (Edit VIP in vip-configmap.yaml).
* Deploy Kubernetes Dashboard from `kubectl create -f https://git.io/kube-dashboard`. Dashboard ingress (from dashboard dir)
* Deploy Heapster (from dashboard dir)
* Add local DNS server to DNS deployment (kubedns args `--nameservers=10.178.11.220`) or load `kubedns-configmap.yaml` (If not configured as server default DNS on resolv.conf).
* Deploy NFS StorageClass from nfs-storageclass dir (NFS server must have no_root_squash).
* Set the StorageClass as default with `kubectl patch storageclass default -p '{"metadata":{"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}'`.
* Deploy InfluxDB from influx-grafana dir (influx.yaml)
* Install Helm (if not installed by playbook)
* Fix Helm RBAC permissions with:
    `kubectl create serviceaccount --namespace kube-system tiller`
    `kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller`
    `kubectl edit deploy --namespace kube-system tiller-deploy #and add the line "serviceAccount: tiller" to spec/template/spec`
* Deploy Grafana from Helm chart:
    `helm install --name grafana --set server.serviceType=NodePort --set server.persistentVolume.enabled=false --set server.installPlugins=raintank-kubernetes-app --set server.adminPassword=admin stable/grafana`
* Deploy Grafana ingress from grafana-helm-ingress.yaml
* Deploy Grafana Kubernetes app
    - Deploy Graphite monitoring db (graphite dir dep/svc)
    - Create a Graphite datasource (http://graphite.default.svc.kube.com:80)
    - Configure Kubernetes Grafana App
      ```
      - Go to the Cluster List page via the Kubernetes app menu.
      - Click the New Cluster button.
      - URL from "kubectl cluster-info", Access == proxy.
      - Fill in the Auth details for your cluster (ca.crt, apiserver-kubelet-client.crt and apiserver-kubelet-client.key from /etc/kubernetes/pki/). Check "TLS Client Auth" and "With CA Cert".
      - Choose the Graphite datasource that will be used for reading data in the dashboards.
      - Fill in the details for the Carbon host that is used to write to Graphite. Use ClusterIP for the Graphite Write Server
      - Click Deploy. This will deploy a DaemonSet, to collect health metrics for every node, and a pod that collects cluster metrics.
      ```
      - Fix Snap permissions
          `kubectl create serviceaccount --namespace kube-system snap`
          `kubectl create clusterrolebinding snap-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:snap`
          `kubectl edit deploy --namespace kube-system snap-kubestate-deployment` add `serviceAccount: tiller` to spec/template/spec

* Deploy Weavescope from weavescope dir (optional)
* Deploy Rook (optional for Ceph storage across all nodes)
    kubectl apply -f https://raw.githubusercontent.com/rook/rook/master/demo/kubernetes/rook-operator.yaml
    kubectl apply -f https://raw.githubusercontent.com/rook/rook/master/demo/kubernetes/rook-cluster.yaml
    kubectl apply -f https://raw.githubusercontent.com/rook/rook/master/demo/kubernetes/rook-storageclass.yaml
    `# Repeat this step for all namespaces you want to deploy PersistentVolumes with Rook in`
    kubectl get secret rook-rook-user -oyaml | sed "/resourceVer/d;/uid/d;/self/d;/creat/d;/namespace/d" | kubectl -n kube-system apply -f -
    `# In order to make Rook the default Storage Provider by making the `rook-block` Storage Class the default, run this:`
    `kubectl patch storageclass rook-block -p '{"metadata":{"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}'`
* Deploy Cinder StorageClass from cinder-storageclass dir (depends on Kubernetes 1.7)

### References:
* [https://github.com/luxas/kubeadm-workshop](https://github.com/luxas/kubeadm-workshop)
* [https://github.com/ReSearchITEng/kubeadm-playbook](https://github.com/ReSearchITEng/kubeadm-playbook)
* [https://github.com/grafana/kubernetes-app](https://github.com/grafana/kubernetes-app)

------------------------------------------------------------------------------

### Directory listing

   `cinder-storageclass` - Creates a Openstack Cinder StorageClass (Depends on 1.7)
   `configmap-overlap-example` - Example of overlapping an existing file with a `ConfigMap file.
   `dashboard` - Kubernetes Dashboard/Heapster deployment with ingress.
   `gitlab` - Gitlab deployment with ingress.
   `grafana-helm-ingress.yaml` - Ingress file for the Helm Grafana deployment.
   `graphite` - Graphite deployment for the Kubernetes-Grafana plugin.
   `influx` - Influx database deployment.
   `jenkins` - Jenkins deployment with ingress.
   `keepalived-vip` - Keepalived deployment to create a VIP on all Kubernetes nodes.
   `kubedns-configmap.yaml` - Kubedns ConfigMap to allow alternate upstream DNS `server.
   `nfs-pv-pvc` - NFS PersistentVolume and PersistentVolumeClass example deployment.
   `nfs-storageclass` - NFS StorageClass.
   `nginx-lb` - Nginx deployment example with LoadBalancer.
   `openstack.conf` - Config to allow integration to Openstack cloud provider.
   `traefik` - Traefik Ingress controller deployment
   `weavescope` - Weavescope monitoring deployment

------------------------------------------------------------------------------

# Command Aliases/Funtions in .bashrc

    source <(kubectl completion bash)

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

    wpod() {
        NS=$@
        NAMESPACE=${NS:-"--all-namespaces"}
        if [ "$NAMESPACE" != "--all-namespaces" ]
          then
          NAMESPACE="-n ${NS}"
        fi

        watch kubectl get pods $NAMESPACE
    }

    kexec() {
        POD=$1
        INPUT_INDEX=$2
        INDEX="${INPUT_INDEX:-1}"
        PODS=`kubectl get pods --all-namespaces|grep ${POD} |head -${INDEX} |tail -1`
        PODNAME=`echo ${PODS} |awk '{print $2}'`
        echo "Pod: ${PODNAME}"
        echo
        NS=`echo ${PODS} |awk '{print $1}'`
        kubectl exec -it --namespace=${NS} ${PODNAME} /bin/bash
    }

    kdesc() {
        POD=$1
        INPUT_INDEX=$2
        INDEX="${INPUT_INDEX:-1}"
        PODS=`kubectl get pods --all-namespaces|grep ${POD} |head -${INDEX} |tail -1`
        PODNAME=`echo ${PODS} |awk '{print $2}'`
        echo "Pod: ${PODNAME}"
        echo
        NS=`echo ${PODS} |awk '{print $1}'`
        kubectl describe pod --namespace=${NS} ${PODNAME}
    }
    export -f kdesc

    alias ksvc='kubectl get services --all-namespaces'
    alias kpod='kubectl get pods --all-namespaces'
    alias kedp='kubectl get endpoints --all-namespaces'


## Set default StorageClass
    kubectl patch storageclass managed-nfs-storage -p '{"metadata":{"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}'

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

Add to `/etc/kubernetes/manifests/kube-apiserver.yaml` on master node (end of parameters)

    - --cloud-provider=openstack
    - --cloud-config=/etc/kubernetes/openstack.conf


Add to `/etc/kubernetes/manifests/kube-controller-manager.yaml` on master node(start of parameters)

    - --cloud-provider=openstack
    - --cloud-config=/etc/kubernetes/openstack.conf

Follow logs:

    journalctl -r -u kubelet

## Fix permission for RBAC (Not to be used)

    kubectl create clusterrolebinding permissive-binding --clusterrole=cluster-admin --user=admin --user=kubelet --group=system:serviceaccounts

    kubectl create clusterrolebinding add-on-cluster-account --clusterrole=cluster-admin --serviceaccount=default:default

------------------------------------------------------------------------------

## Install on Openstack Heat (openrc)

sudo pip install python-openstackclient
sudo pip install python-heatclient
sudo pip install python-swiftclient
sudo pip install python-glanceclient
sudo pip install python-novaclient

    export OS_USERNAME=admin
    export OS_PASSWORD=admin
    export OS_TENANT_NAME=admin
    export OS_TENANT_ID=?????????????
    export OS_PROJECT_NAME=admin
    export OS_DEFAULT_DOMAIN=default
    export OS_AUTH_URL=http://public.fuel.local:5000/v2.0
    export OS_REGION_NAME=RegionOne
    export STACK_NAME=KubernetesStack
    #
    # Kubernetes options
    #
    export NUMBER_OF_MINIONS=2
    export MAX_NUMBER_OF_MINIONS=5
    export MASTER_FLAVOR=m1.medium
    export MINION_FLAVOR=m1.medium
    export EXTERNAL_NETWORK=admin_floating_net
    export DNS_SERVER=8.8.8.8
    export CREATE_IMAGE=false
    export IMAGE_ID:???????????????????
    export OPENSTACK_IMAGE_NAME=CentOS-7-x86_64-GenericCloud-1611.vmdk
    export IMAGE_FILE=CentOS-7-x86_64-GenericCloud-1611.vmdk
    export SWIFT_SERVER_URL=http://public.fuel.local:8080
    export ENABLE_PROXY=false
    export LBAAS_VERSION=v2

## Start deploy:

    cd kubernetes # Or whichever path you have extracted the release to
    KUBERNETES_PROVIDER=openstack-heat ./cluster/kube-up.sh

------------------------------------------------------------------------------
