# openshift-cluster-bootstrap

This repository demonstrate the usage of OpenShift-GitOps and a secrets manager like Sealed Secrets or Hashicorp Vault. 
The focus lies on main cluster configuration.

This repository is never to be considered as finished ever, since new cluster configuration may happen at any time. 

## Initialize

Before gitops can be used some basic setup must be done. A shell script has been prepared to do that for you:

1. Deploy the OpenShift GitOps operator: 
```
./init_GitOps.sh -o enable-cluster-admin
```

This will deploy the Redhat Gitops operator, the Application of Applications and optionally Sealed Secrets and/or Hashicorp Vault. 

NOTE: Hashicorp Vault is as of today installed only. Nothing else is done yet.

2. Download the Sealed Secret certificate for this specific cluster.

The following script will store the certificate into ~/.bitname/
```
./scripts/sealed_secrets/get-sealed-secret-key.sh
```

## Repository structure

Currently, the following directory structure is used: 

``` 
.
├── init_GitOps.sh
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
│   │   │   ├── ...
│   │   └── values.yaml
│   ├── management-cluster <5>
│   │   └── ...
│   └── production-cluster <6>
│       └── ...
├── components <7>
│   ├── apps <8>
│   │   ├── ...
│   └── operators <9>
│   │   └── ...
├── tenants 
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