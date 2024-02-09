# Platform Engineering on Kubernetes (GKE version)

This repo is attempting to implement the Conference app from the "Platform Engineering on Kubernetes" book on a GKE cluster.

Original sources:
- repo: https://github.com/salaboy/platforms-on-k8s
- book: https://www.salaboy.com/book/

# Prerequisites

## Tools

This repo expects the following tools to be installed on your workstation:
- terraform
- gcloud (to configure kubectl, so can be skipped if you know how to do that otherwise)
- kubectl
- helm

FWIW GCP's Cloud Shell instances come with all above preinstalled and configured.

## DNS

To make the app available on an HTTPS endpoint on GKE without port-forwarding to local the assumption is made that the reader already has a DNS managed zone on GCP. `tf/network/dns` module will require the project ID where it is managed, so that it can create the NS and A records that would point at the Nginx-Ingress load balancer.
The app should be available at `http(s)://conference.gke.${YOUR_DOMAIN}`.
By default the module and its outputs are commented out.

If you want to give above a try just remove the comments from the module and the outputs below it and provide the required variables. Then when you run helm install steps below you would need to choose the commands that mention the presence of the created DNS zone.

# General Layout

## Cluster

The GKE cluster is created with Terraform. All files are in `tf` folder with the following structure:
- `network` - module that builds out the VPC-related resources, as well as DNS.
- `kube` - module that places into above VPC a regional GKE cluster with presence in 2 AZs. It also create 2 node pools: `traffic` and `default`. The `traffic` pool is tainted for nginx-ingress pods only (its helm chart already has the required tolerations).
If you don't have local Terraform setup, you can use GCP's cloud shell as it comes with TF installed and can be easily configured to authenticate with the required project.

## Charts

The `charts` directory contains several Helm charts that you might or might not need based on you choice around the DNS setup. The Conference app is in the `charts/conference-app` folder.

# Step By Step

## Create the cluster

1. Make sure compute and container APIs are enabled in your project.
1. Change directory to the `tf` folder and run below commands to create the infrastructure:

    ```
    terraform init
    terraform apply
    ```

    **NOTE!** GCP charges $0.10 per GKE node per hour. The total cost can add up over time. Make sure you destroy all the infrastructure once you're done with `terraform destroy`.

    Cluster creation should take around 15 mins. Cluster itself usually takes around 10 mins and node pools will add up to 5 minutes to that.
1. Once cluster is created, you can configure your local kubectl to interact with it:
    ```
    gcloud container clusters get-credentials $(terraform output -raw kubernetes_cluster_name) --region $(terraform output -raw region)
    ```
## Deploy Ingress (Only if DNS is configured)
If you confired a DNS zone you will need to deploy the Nginx-Ingress that will take over the dedicated IP and route requests to the services. To deploy an Nginx-Ingress to our cluster run:

```
helm install nginx-ingress ../charts/nginx-ingress/ --namespace ingress --create-namespace --set controller.service.loadBalancerIP=$(terraform output -raw lb_ip) --wait
```
It will take some time for the load balancer to get created and be available from the outside. Running below command should display the external IP:

```
$ kubectl get svc -n ingress
NAME                       TYPE           CLUSTER-IP    EXTERNAL-IP     PORT(S)                      AGE
nginx-ingress-controller   LoadBalancer   10.52.6.246   34.34.34.34   80:30339/TCP,443:30944/TCP   51s    
```

To enable HTTPS (TLS) for our service we need to install cert-manager that will be creating them automatically for our Ingress resources:

```
$ kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.1/cert-manager.crds.yaml
$ helm install cert-manager --namespace cert-manager --create-namespace --version v1.14.1 ../charts/cert-manager --wait
```

## Deploy A Test Service
1. Install a small testing app to verify your installation:
    ```
    # If you didn't create a dedicated DNS zone:
    helm install kuard ../charts/test-app/ --namespace app --create-namespace
    
    # If you have created a dedicated DNS zone:
    GKE_DOMAIN=$(terraform output -raw dns_name | rev | cut -c2- | rev)
    helm install kuard ../charts/test-app/ --namespace app --create-namespace --set url=$GKE_DOMAIN
    ```
2. Accessing the app:
    
    a. If you didn't create a dedicated DNS zone use port forwarding to access the app:
    ```
    kubectl port-forward svc/kuard -n app 8080:80
    ```
    You should be able to open the app in your local browser on port 8080.

    b. If you did setup a managed DNS zone and followed the Ingress installation part above, you should be able to access your service on https://kuard.gke.{YOUR_DOMAIN}

## Deploy the Conference App
To install the app from the book run below:
```
# If you didn't create a dedicated DNS zone:
helm install conference --namespace app --create-namespace --version v1.0.0 ../charts/conference-app --set install.ingress=false

# If you have created a dedicated DNS zone:
GKE_DOMAIN=$(terraform output -raw dns_name | rev | cut -c2- | rev)
helm install conference --namespace app --create-namespace --version v1.0.0 ../charts/conference-app --set url=$GKE_DOMAIN
```
App takes few minutes to come fully online. Make sure that all pods in the `app` namespace are in the READY state. To access the page:
1. Through port-forward:
    ```
    kubectl port-forward svc/frontend -n app 8080:80
    ```
1. Through ingress and DNS: https://conference.gke.{YOUR_DOMAIN}

# Clean Up

Don't forget to run `terraform destroy` to remove all the infrastructure and save yourself some money.