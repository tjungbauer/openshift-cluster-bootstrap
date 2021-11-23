# openshift-cluster-bootstrap

This repository demonstrate the usage of OpenShift-GitOps and Sealed Secreets to

- Deploy the Operators OpenShift-Gitops and Sealed Secrets
- Create cluster configuration like: 
   - install other operators
   - configure oauth 

This repository is never to be considered as finished ever, since new cluster configuration may happen at any time. 

## Initialize

Before gitops can be used some basic setup must be done. 2 shell scripts have been prepared:

1. Deploy the OpenShift GitOps operator: 
```
./00-Initialize-Cluster.sh -o=enable-cluster-admin [-d=true]
```

The switch *-d* defines if a dry-run shall be done or not. 

2. Deploy the Application of Applications for a sepcific, which will create all ArgoCD applications. 
For better overview for each cluster a new ArgoCD project will be created.

NOTE: This is curretly the only ArgoCD application which will synchronize itself. 

```
./01-Create-App-of-Apps.sh -o=management-cluster [-d=true]
```

The switch *-d* defines if a dry-run shall be done or not. 

3. Download the Sealed Secret certificate for this specific cluster.

The following script will store the certificate into ~/.bitname/
```
./scripts/sealed_secrets/get-sealed-secret-key.sh
```


## Prepare Cluster Configuration

Some configuration will be different from cluster to cluster and must be set accoridngly. If you would like to configure authentication, prepare the following: 

### Cluster Authentication htpasswd and ldap 
Both, htpasswd and ldap atuehtnication, require a secret to store senstive information. 

These secrets must be created first using *kubeseal* on the command line. Moreover, for ldap a certificate must be used (when ldaps is required)

NOTE: Sealed Secret operator and certificates must be running and available. 

1. Create htpasswd sealed secret: 

```
echo -n 'admin:$apr1$6LA9fDGq$lJ.j5SCNOXcRvo8ihwKCJ.
andrew:$apr1$dZPb2ECf$ercevOFO5znrynUfUj4tb/
karla:$apr1$FQx2mX4c$eJc21GuVZWNg1ULF8I2G31
opentlc-mgr:$apr1$6LA9fDGq$lJ.j5SCNOXcRvo8ihwKCJ.
user1:$apr1$keT05r.g$phjnGx.xLm1tZoFk41hrP1' | oc create secret generic htpasswd-secret  --dry-run=client --from-file=htpasswd=/dev/stdin -o yaml -n openshift-config \
| kubeseal --controller-namespace=sealed-secrets --controller-name=sealed-secrets-controller --format yaml > clusters/management-cluster/config/oauth-cluster/overlays/sealed-htpasswed-secret.yaml
```

2. Create the sealed secret for ldap bindPassword

```
echo -n 'LDAPbindPassword-HERE' | oc create secret generic ldap-secret --dry-run=client --from-file=bindPassword=/dev/stdin -o yaml -n openshift-config \
| kubeseal --controller-namespace=sealed-secrets --controller-name=sealed-secrets-controller --format yaml > clusters/management-cluster/config/oauth-cluster/overlays/sealed-ldap-bindpassword-secret.yaml
```

3. Replace ldap certificate 
Copy your certificate into the file: *clusters/management-cluster/config/oauth-cluster/overlays/ca.crt*

## Repository structure

Currently, the following directory structure is used: 

``` 
├── 00-Initialize-Cluster.sh
├── 01-Create-App-of-Apps.sh
├── README.md
├── bootstrap <1>
│   ├── clusters
│   ├── openshift-gitops
│   └── sealed-secrets
├── clusters
│   ├── all
│   └── management-cluster <2>
│       ├── argocd-applications <3>
│       │   ├── advanced-cluster-security
│       │   ├── console-banner
│       │   ├── elasticsearch
│       │   ├── etcd-encryption
│       │   ├── jaeger
│       │   ├── kiali
│       │   ├── node-environment-setup
│       │   ├── oauth
│       │   ├── openshift-logging
│       │   ├── overlays
│       │   ├── pipelines
│       │   ├── resource-locker
│       │   ├── self-provisioner
│       │   └── servicemesh 
│       └── config <4>
│           ├── acs-config
│           ├── console-banner
│           ├── elasticsearch
│           ├── etcd-encryption
│           ├── jaeger
│           ├── kiali
│           ├── node-environment-setup
│           ├── oauth-cluster
│           ├── openshift-logging
│           ├── pipelines
│           ├── resource-locker
│           ├── self-provisioner
│           └── servicemesh
├── components <5> 
│   ├── apps <6> 
│   │   ├── operator-advanced-cluster-security
│   │   ├── operator-elasticsearch
│   │   ├── operator-jaeger
│   │   ├── operator-kiali
│   │   ├── operator-openshift-gitops
│   │   ├── operator-openshift-logging
│   │   ├── operator-openshift-pipelines
│   │   ├── operator-openshift-servicemesh
│   │   ├── operator-resource-locker
│   │   └── operator-sealed-secrets
│   ├── argocd-applications <7>
│   │   └── app-of-apps
│   └── clusterconfig <8>
│       ├── authentication-identityprovider
│       ├── console-banner
│       ├── etcd-encryption
│       ├── init_advanced_cluster
│       ├── init_openshift_logging
│       ├── node-environment-setup
│       └── self-provisioner
└── scripts <9>
    ├── etcd-encryption
    │   └── check_encryption_status.sh
    └── sealed_secrets
        ├── get-sealed-secret-key.sh
        └── replace-sealed-secrets-secret.sh
```

<1> ```bootstrap``` is used by the 2 initializations scripts only.\
<2> ```clusters``` holds the definition per cluster. Since every cluster might have a different configuration, each cluster will get its own directory. Here our first cluster is called *management-cluster*\
<3> ```argocd-applications``` create the actual applications for ArgoCD. These is what is visible on the ArgoCD UI 
<4> ```config``` specific cluster configuration, gets set here. This is done using kustomization patches 
<5> ```components``` basic components for the configuration. <3> and <4> are using the entities in this folder and are patching as required.  
<6> ```app``` This folder defines additional applications which shall be installed. Currently holds all operators, which will be deployed on the OpenShit clusters 
<7> ```argocd-application``` soley responsible for the Application of Applications 
<8> ```clusterconfig``` bases for cluster configuration used/patched by <4>
<9> ```scripts``` helper scripts to get sealed secret certificate or verify etcd encryption status

## Currently Supported Configurations 



## TODO 

cluter-authetnciation creates: v4-0-config-user-idp-0-ca which causes argocd to be not in sync

test if ldap-oaith can be disabled

acs-pipeline-tasks


setting up:
  1. clusters/mgmt-cluster/argocd ... add new application 
  2. add apps and operators to components/apps
  3. add cluster config to components/clusterconfig 
  4. if patching for cluster is required add patching to cluster/mgmt-cluster/config