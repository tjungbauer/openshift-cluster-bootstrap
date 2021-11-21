
WIP

TODO 

remove cluster/mgmt../config/all --> also from all kustomizaton.yaml

ldap & htpasswd -> secrets integration is missing

ACS production setup

jaeger
kiali
service mesh
pipeline
acs-pipeline-tasks

applicationset --> argocd

setting up:
  1. clusters/mgmt-cluster/argocd ... add new application 
  2. add apps and operators to components/apps
  3. add cluster config to components/clusterconfig 
  4. if patching for cluster is required add patching to cluster/mgmt-cluster/config