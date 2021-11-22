
WIP


Config must be prepared: 

i.e. ouath htpasswd and LDAP 

# HTPASSWD: Create secret using Sealed-Secrets
echo -n 'admin:$apr1$6LA9fDGq$lJ.j5SCNOXcRvo8ihwKCJ.
andrew:$apr1$dZPb2ECf$ercevOFO5znrynUfUj4tb/
karla:$apr1$FQx2mX4c$eJc21GuVZWNg1ULF8I2G31
opentlc-mgr:$apr1$6LA9fDGq$lJ.j5SCNOXcRvo8ihwKCJ.
user1:$apr1$keT05r.g$phjnGx.xLm1tZoFk41hrP1' | oc create secret generic htpasswd-secret  --dry-run=client --from-file=htpasswd=/dev/stdin -o yaml -n openshift-config \
| kubeseal --controller-namespace=sealed-secrets --controller-name=sealed-secrets-controller --format yaml > clusters/management-cluster/config/oauth-cluster/overlays/sealed-htpasswed-secret.yaml


# CREATE LDAP Secret for bindPassword
echo -n 'LDAPbindPassword-HERE' | oc create secret generic ldap-secret --dry-run=client --from-file=bindPassword=/dev/stdin -o yaml -n openshift-config \
| kubeseal --controller-namespace=sealed-secrets --controller-name=sealed-secrets-controller --format yaml > clusters/management-cluster/config/oauth-cluster/overlays/sealed-ldap-bindpassword-secret.yaml

# COPY LDAP certificate into the following file 
clusters/management-cluster/config/oauth-cluster/overlays/ca.crt

TODO 

cluter-authetnciation creates: v4-0-config-user-idp-0-ca which causes argocd to be not in sync

test if ldap-oaith can be disabled

ACS production setup

acs-pipeline-tasks

applicationset --> argocd

setting up:
  1. clusters/mgmt-cluster/argocd ... add new application 
  2. add apps and operators to components/apps
  3. add cluster config to components/clusterconfig 
  4. if patching for cluster is required add patching to cluster/mgmt-cluster/config