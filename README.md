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

