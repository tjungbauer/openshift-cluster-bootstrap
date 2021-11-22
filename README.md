
WIP


# HTPASSWD: Create secret using Sealed-Secrets
echo -n 'admin:$apr1$6LA9fDGq$lJ.j5SCNOXcRvo8ihwKCJ.
andrew:$apr1$dZPb2ECf$ercevOFO5znrynUfUj4tb/
karla:$apr1$FQx2mX4c$eJc21GuVZWNg1ULF8I2G31
opentlc-mgr:$apr1$6LA9fDGq$lJ.j5SCNOXcRvo8ihwKCJ.
user1:$apr1$keT05r.g$phjnGx.xLm1tZoFk41hrP1' | oc create secret generic htpasswd-secret  --dry-run=client --from-file=htpasswd=/dev/stdin -o yaml -n openshift-config \
| kubeseal --controller-namespace=sealed-secrets --controller-name=sealed-secrets-controller --format yaml > clusters/management-cluster/config/oauth-cluster/overlays/sealed-htpasswed-secret.yaml


$ oc create secret generic htpass-secret --from-file=htpasswd=<path_to_users.htpasswd> -n openshift-config 

$ oc create secret generic ldap-secret --from-literal=bindPassword=<secret> -n openshift-config 
apiVersion: v1
kind: Secret
metadata:
  name: ldap-secret
  namespace: openshift-config
type: Opaque
data:
  bindPassword: <base64_encoded_bind_password>


echo -n 'LDAPbindPassword-HERE' | oc create secret generic ldap-secret --dry-run=client --from-file=bindPassword=/dev/stdin -o yaml -n openshift-config \


TODO 

ldap & htpasswd -> secrets integration is missing

ACS production setup

acs-pipeline-tasks

applicationset --> argocd

setting up:
  1. clusters/mgmt-cluster/argocd ... add new application 
  2. add apps and operators to components/apps
  3. add cluster config to components/clusterconfig 
  4. if patching for cluster is required add patching to cluster/mgmt-cluster/config