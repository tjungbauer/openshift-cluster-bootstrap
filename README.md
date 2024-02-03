[![No Maintenance Intended](http://unmaintained.tech/badge.svg)](http://unmaintained.tech/)


# DEPRECATED 

This repository was replaced by https://github.com/tjungbauer/openshift-clusterconfig-gitops please use the new repo.


## openshift-cluster-bootstrap

This repository demonstrate the usage of OpenShift-GitOps and a secrets manager like Sealed Secrets or Hashicorp Vault.  
The focus lies on main cluster configuration.

This repository is never to be considered as finished ever, since new cluster configuration may happen at any time. 

## Initialize

Before gitops can be used some basic setup must be done. A shell script has been prepared to do that for you:

1. Deploy the OpenShift GitOps operator: 
```
./init_GitOps.sh
```

This will deploy the Redhat Gitops operator, the Application of Applications and optionally Sealed Secrets and/or Hashicorp Vault. 

NOTE: Hashicorp Vault is as of today installed only. Nothing else is done yet.

2. Download the Sealed Secret certificate for this specific cluster.

The following script will store the certificate into ~/.bitname/
```
./scripts/sealed_secrets/get-sealed-secret-key.sh
```

## Help Charts Repository

Most Helm Charts can be found at: https://charts.stderr.at/ 


