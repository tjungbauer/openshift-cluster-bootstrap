# openshift-cluster-bootstrap

This repository demonstrate the usage of OpenShift-GitOps and a secrets manager like Sealed Secrets or Hashicorp Vault. 
The focus lies on main cluster configuration.

This repository is never to be considered as finished ever, since new cluster configuration may happen at any time. 

## Initialize

Before gitops can be used some basic setup must be done. 2 shell scripts have been prepared:

1. Deploy the OpenShift GitOps operator: 
```
./00-Initialize-Cluster.sh -o enable-cluster-admin
```

This will deploy the Redhat Gitops operator and optionally Sealed Secrets and/or Hashicorp Vault. 

2. Deploy the Application of Applications. This App of Apps will monitor new Applications and Applicationsets and will automatically create them for you. 

NOTE: This is curretly the only ArgoCD application which will synchronize itself. 

```
./01-Create-App-of-Apps.sh
```

NOTE: Hashicorp Vault is as of today installed only. Nothing else is done yet.

3. Download the Sealed Secret certificate for this specific cluster.

The following script will store the certificate into ~/.bitname/
```
./scripts/sealed_secrets/get-sealed-secret-key.sh
```

## Repository structure

Currently, the following directory structure is used: 

``` 
.
├── 00-Initialize-Cluster.sh
├── 01-Create-App-of-Apps.sh
├── README.md
├── bootstrap <1>
│   ├── ...
├── clusters <2>
│   ├── all <3>
│   │   └── clusterconfig
│   │       ├── ...
│   ├── argocd-object-manager <4>
│   │   ├── Chart.yaml
│   │   ├── templates
│   │   │   ├── app_demo_app_advanced-cluster-security.yaml
│   │   │   ├── app_init_advanced-cluster-security.yaml
│   │   │   ├── appset_generic_cluster_config.yaml
│   │   │   ├── appset_install_advanced_cluster_management.yaml
│   │   │   ├── appset_install_advanced_cluster_security.yaml
│   │   │   ├── appset_install_elasticsearch.yaml
│   │   │   ├── appset_install_kiali.yaml
│   │   │   ├── appset_install_oauth.yaml
│   │   │   ├── appset_install_openshift-logging.yaml
│   │   │   ├── appset_install_openshift-pipelines.yaml
│   │   │   ├── appset_install_openshift-servicemesh.yaml
│   │   │   ├── appset_install_openshift-tracing.yaml
│   │   │   ├── appset_install_quay.yaml
│   │   │   ├── appset_install_redhat_sso\ copy.yaml
│   │   │   ├── appset_install_redhat_sso.yaml
│   │   │   ├── appset_install_resourcelocker.yaml
│   │   │   └── argocd-project.yaml
│   │   └── values.yaml
│   ├── management-cluster <4>
│   │   └── ...
│   └── production-cluster <5>
│       └── ...
├── components <7>
│   ├── apps <8>
│   │   ├── ...
│   └── operators <9>
│   │   └── ...
└── scripts <10>
    ├── etcd-encryption
    └── sealed_secrets
```

<1> ```bootstrap``` is used by the 2 initializations scripts only.\
<2> ```clusters``` holds the definition per cluster. Since every cluster might have a different configuration, each cluster will get its own directory.
<3> ```all``` Configuration which is valid for all clusters goes in here. \
<4> ```argocd-object-manager``` contains Applicationset and Application with their configuration. This folder is monitored by the App of Apps. \
<5> ```management-cluster``` Example cluster ... typically this is the cluster where ArgoCD is installed\ 
<6> ```production-cluster``` 2nc Example cluster \
<7> ```components``` basic components for the configuration. <3> and <4> are using the entities in this folder and are patching as required.  \
<8> ```app``` This folder defines additional applications which shall be installed. \
<9> ```operators``` Operators which might be installed are stored here. \
<10> ```scripts``` helper scripts to get sealed secret certificate or verify etcd encryption status\



## How to ... 


### add a new ArgoCD Application/Applicationset

1. Go to ```clusters/argocd-object-manager``` 
2. At **templates/** add a new yaml file as
.. If **Applicationset**:
   Change line 1 and 37 and replace the name of the parameter with one of your own. For example: {{- with .Values.generic_clusterconfig }} --> change "generic_clusterconfig"
.. If **Application**: 
   Change the parameters at several places here

3. Add an appropriate configuration into the values.yaml  For example:

```
install_openshift_logging:
  appsetname: openshift-logging
  path: components/operators/openshift-logging/overlays/stable
  generatorclusters: []

install_openshift_servicemesh:
  appsetname: install-servicemesh
  path: components/operators/openshift-servicemesh/overlays/stable
  generatorlist:
    - clustername:  *mgmtclustername
      clusterurl: *mgmtcluster
    - clustername:  *prodclustername
      clusterurl: *prodcluster
  autosync_enabled: false # 
```

NOTE: The helm chart currently supports the generators cluster and list. With the parameter **generatorclusters** respectively **generatorlist**
Both contain a list of clusters where the Applicationsset shall be deployed. The first one required a label name, the second one a lust of clustername and URLs.

### add a new configuration for all clusters? 

1. Go to ```clusters/all/clusterconfig``` 
2. Put your configuration into the templates folder ... copy an existing one for best result :)

NOTE: All templates start with a line like: ```{{- if .Values.etcd_encryption.enabled }}```. This allows to enable or disable configuration for specific clusters. 

3. In the appropriate values files for the cluster, add you parameters. 




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


4. ConsoleLinks must be modified to your actual domain 

Currently 2 are used, where the href must be changed accordingly: 

1. ACS: clusters/managemet-cluster/config/acs-config/overlays
2. Logging: clusters/managemet-cluster/config/openshift-logging/overlays

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
<3> ```argocd-applications``` create the actual applications for ArgoCD. These is what is visible on the ArgoCD UI\ 
<4> ```config``` specific cluster configuration, gets set here. This is done using kustomization patches\ 
<5> ```components``` basic components for the configuration. <3> and <4> are using the entities in this folder and are patching as required.  \
<6> ```app``` This folder defines additional applications which shall be installed. Currently holds all operators, which will be deployed on the OpenShit clusters\
<7> ```argocd-application``` soley responsible for the Application of Applications\ 
<8> ```clusterconfig``` bases for cluster configuration used/patched by <4>\
<9> ```scripts``` helper scripts to get sealed secret certificate or verify etcd encryption status\

## How to add a new configuration? 

Easiest way is to copy and existing configuration and modify it :)

1. Add the basic cluster configuration to *components/clusterconfig*. This about the items which might need a patch. Follow kustomize principle regarding *base* and *overlays* 
2. IF your want to deploy an operator use the folder *components/apps* instead 
3. Create *clusters/<your cluster>/config* 
4. Create the ArgoCD application in *clusters/<your cluster>/argocd-applications* 
5. Add the new reference to argocd application to *clusters/<your cluster>/argocd-applications/overlays/kustomize.yaml*


## TODO 

cluter-authetnciation creates: v4-0-config-user-idp-0-ca which causes argocd to be not in sync



