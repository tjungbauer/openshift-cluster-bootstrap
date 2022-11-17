#!/bin/bash
set -euf -o pipefail
RED='\033[37;41m'  # White text with red background
CYAN_BG='\033[30;46m' # Black text with cyan background
GREEN='\033[30;42m'  # Black text with green background
NC='\033[0m' # No Color
TIMER=45 # Sleep timer to initially wait for the gitops-operator to be deployed before starting testing the deployments. 
RECHECK_TIMER=10

HELM="/usr/bin/env helm"
HELM_CHARTS="https://charts.stderr.at/"

function error() {
    echo "$1"
    exit 1
}

# Ask which Secret Manager should be installed
function verify_secret_mgmt() {
  printf "\nPlease select one of the supported Secrets Manager.\n\n"
  printf "Press 1, 2, 3\n"
  select svn in "Sealed-Secrets" "Hashicorp-Vault" "None"; do
        case $svn in
            Sealed-Secrets ) echo "Installing Sealed Secrets"; install_sealed_secrets; break;;
            Hashicorp-Vault) echo "Installing Hashicorp Vault"; install_vault; break;;
            None) echo "Using NO Secret Manager. Exiting"; exit;; 
        esac
    done  
}

function add_helm_repo() {

  printf "\nAdding Helm Repo %s\n" "${HELM_CHARTS}"
  $HELM repo add --force-update tjungbauer ${HELM_CHARTS}
  $HELM repo update

}

function check_channel() {
  printf "\nWhich channel do you want to use? stable or latest?\n\n"
  printf "Press 1 or 2\n"
  select sl in "Stable" "Latest"; do
    case $sl in
        Stable ) echo "Starting Deployment using STABLE channel"; deploy "stable"; break;;
        Latest ) echo "Starting Deployment using LATEST channel"; deploy "latest"; break;;
    esac
  done
}

# Deploy openshift-gitops-operator
function deploy() {
  printf "\n%bDeploying OpenShift GitOps Operator%b\n" "${RED}" "${NC}"

  add_helm_repo

  $HELM upgrade --install --set 'gitops.subscription.channel='$1 --set 'gitops.enabled=true' --set 'gitops.clusterAdmin=true' --namespace=openshift-operators openshift-gitops-operator tjungbauer/openshift-gitops

  printf "\nGive the gitops-operator some time to be installed. %bWaiting for %s seconds...%b\n" "${RED}" "${TIMER}" "${NC}"
  TIMER_TMP=0
  while [[ $TIMER_TMP -le $TIMER ]]
    do 
      #echo $TIMER_TMP
      echo -n "."
      sleep 1
      let "TIMER_TMP=TIMER_TMP+1"
    done
  echo "Let's continue"
  #sleep $TIMER

  printf "\n%bWaiting for operator to start. Chcking every %s seconds.%b\n" "${RED}" "${RECHECK_TIMER}" "${NC}"
  until oc get deployment gitops-operator-controller-manager -n openshift-operators
  do
    sleep $RECHECK_TIMER;
  done

  printf "\n%bWaiting for openshift-gitops namespace to be created. Checking every %s seconds.%b\n" "${RED}" "${RECHECK_TIMER}" "${NC}"
  until oc get ns openshift-gitops
  do
    sleep $RECHECK_TIMER;
  done

  printf "\n%bWaiting for deployments to start. Checking every %s seconds.%b\n" "${RED}" "${RECHECK_TIMER}" "${NC}"
  until oc get deployment cluster -n openshift-gitops
  do
    sleep $RECHECK_TIMER;
  done

  echo "Waiting for all pods to be created"
  waiting_for_argocd_pods

  printf "%bGitOps Operator ready%b\n" "${GREEN}" "${NC}"

  patch_argocd

  deploy_app_of_apps

  #verify_secret_mgmt

  install_sealed_secrets

  install_vault
}

# Be sure that all Deployments are ready
function waiting_for_argocd_pods() {

  deployments=(cluster kam openshift-gitops-applicationset-controller openshift-gitops-redis openshift-gitops-repo-server openshift-gitops-server)
  for i in "${deployments[@]}";
  do
    printf "\n%bWaiting for deployment $i %b\n" "${CYAN_BG}" "${NC}"
    oc rollout status deployment "$i" -n openshift-gitops
  done
}

# PATCH the ArgoCD Operator CRD
function patch_argocd() {
  
  printf "\nLets use our patched ArgoCD CRD\n"

  oc apply -f https://raw.githubusercontent.com/tjungbauer/helm-charts/main/charts/openshift-gitops/PATCH_openshift-gitops-cr.yaml
  oc apply -f https://raw.githubusercontent.com/tjungbauer/helm-charts/main/charts/openshift-gitops/PATCH_openshift-gitops-crb.yaml

  sleep $RECHECK_TIMER
  waiting_for_argocd_pods

  printf "%bGitOps Operator ready... again%b\n" "${GREEN}" "${NC}"

}

# Deploy the Application of Applications
function deploy_app_of_apps() {

  $HELM upgrade --install --values ./clusters/management-cluster/init_app_of_apps/values.yaml --namespace=openshift-gitops app-of-apps ./clusters/management-cluster/init_app_of_apps

}

# Deploy Sealed Secrets if selected
function install_sealed_secrets() {
  printf "\n%bDeploy Sealed Secrets Application into ArgoCD%b\n" "${RED}" "${NC}"
  
  #add_helm_repo
  #$HELM upgrade --install sealed-secrets tjungbauer/sealed-secrets --set 'sealed-secrets.enabled=true'

  printf "\nCreating Secret in OpenShift for Sealed Secrets Helm Repository (charts.stderr.at)\n"
  oc create --dry-run=client secret generic repo-bitnami-sealed-secrets \
  --from-literal=name="Sealed Secrets Helm repo" \
  --from-literal=project=default \
  --from-literal=type=helm \
  --from-literal=url="https://charts.stderr.at/" \
  -o yaml | oc apply --namespace openshift-gitops -f -

  printf "\nLabel Secret\n"
  oc label secret repo-bitnami-sealed-secrets -n openshift-gitops --overwrite=true "argocd.argoproj.io/secret-type=repository"

  printf "\nNow use ArgoCD to deploy sealed-secret\n"

}

# Deploy Hashicorp Vault if selected
function install_vault() {

  printf "\n%bDeploy Hashicorp Vault Application into ArgoCD%b\n" "${RED}" "${NC}"
  
  printf "\nCreating Secret for HashiCorp's Vault Helm Repository\n"
  oc create --dry-run=client secret generic repo-hashicorp-vault \
  --from-literal=name="HashiCorp Vault Helm repo" \
  --from-literal=project=default \
  --from-literal=type=helm \
  --from-literal=url="https://helm.releases.hashicorp.com" \
  -o yaml | oc apply --namespace openshift-gitops -f -

  printf "\nLabel Secret\n"
  oc label secret repo-hashicorp-vault -n openshift-gitops --overwrite=true "argocd.argoproj.io/secret-type=repository"

  printf "\nCreate Application to Deploy Vault\n"

  printf "\nHashiCorp Vault has been installed. Be sure to sync the ArgoCD Application (Auto-Sync has been disabled) and to perform any further configuration\n"

}

$HELM >/dev/null 2>&1 || error "Could not execute helm binary!"

check_channel

#printf "\nDo you wish to continue and install GitOps?\n\n"
#printf "Press 1 or 2\n"
#select yn in "Yes" "No" "Skip"; do
#    case $yn in
#        Yes ) echo "Starting Deployment"; check_channel; break;;
#        No ) echo "Exit"; exit;;
#        Skip) echo -e "${RED}Skip deployment of GitOps and continue with Secret Management${NC}"; verify_secret_mgmt; break;;
#    esac
#done
