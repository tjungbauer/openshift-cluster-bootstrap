#!/bin/bash
set -euf -o pipefail
RED='\033[37;41m'  # White text with red background
CYAN_BG='\033[30;46m' # Black text with cyan background
GREEN='\033[30;42m'  # Black text with green background
NC='\033[0m' # No Color
TIMER=45 # Sleep timer to initially wait for the gitops-operator to be deployed before starting testing the deployments. 
RECHECK_TIMER=10

KUSTOMIZE="/usr/bin/env kustomize"
HELM="/usr/bin/env helm"

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
            Hashicorp-Vault) echo "Installing Hashicorp Vault"; starting_vault; break;;
            None) echo "Using NO Secret Manager. Exiting"; exit;; 
        esac
    done  
}

# Deploy openshift-gitops-operator
function deploy() {
  printf "\n%bDeploying OpenShift GitOps Operator%b\n" "${RED}" "${NC}"

  $HELM upgrade --install --values ./bootstrap/openshift-gitops/values.yaml --namespace=openshift-operators openshift-gitops-operator ./bootstrap/openshift-gitops

  printf "\nGive the gitops-operator some time to be installed. %bWaiting for %s seconds...%b\n" "${RED}" "${TIMER}" "${NC}"
  sleep $TIMER

  printf "\n%bWaiting for operator to start. Chcking every %s seconds.%b\n" "${RED}" "${RECHECK_TIMER}" "${NC}"
  until oc get deployment gitops-operator-controller-manager -n openshift-operators
  do
    sleep $RECHECK_TIMER;
  done

  printf "\n%bWaiting for openshift-gitops namespace to be created. Chcking every %s seconds.%b\n" "${RED}" "${RECHECK_TIMER}" "${NC}"
  until oc get ns openshift-gitops
  do
    sleep $RECHECK_TIMER;
  done

  printf "\n%bWaiting for deployments to start. Chcking every %s seconds.%b\n" "${RED}" "${RECHECK_TIMER}" "${NC}"
  until oc get deployment cluster -n openshift-gitops
  do
    sleep $RECHECK_TIMER;
  done

  echo "Waiting for all pods to be created"
  waiting_for_argocd_pods

  echo "${GREEN}GitOps Operator ready${NC}"

  patch_argocd

  deploy_app_of_apps

  verify_secret_mgmt
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

  oc apply -f bootstrap/openshift-gitops/PATCH_openshift-gitops-cr.yaml

  sleep $RECHECK_TIMER
  waiting_for_argocd_pods

  printf "%bGitOps Operator ready... again%b\n" "${GREEN}" "${NC}"

}

# Deploy the Application of Applications
function deploy_app_of_apps() {

  printf "\n%bDeploy ArgoCD Application of Applications$%b\n" "${RED}" "${NC}"
  printf "This will create an ArgoCD Application of Applications which then automatically creates ArgoCD objects like ApplicationSets ad Application\n"

  $HELM upgrade --install --values ./bootstrap/init_app_of_apps/values.yaml --namespace=openshift-gitops app-of-apps ./bootstrap/init_app_of_apps

}

# Deploy Sealed Secrets if selected
function install_sealed_secrets() {
  printf "\n%bDeploy Selaed Secrets%b\n" "${RED}" "${NC}"
  $KUSTOMIZE build bootstrap/sealed-secrets/base | oc apply -f - 
}

# Deploy Hashicorp Vault if selected
function starting_vault() {

  printf "\nWhile the Helm chart automatically sets up complex resources and exposes the configuration to meet your requirements, 
it does not automatically operate Vault. %bYou are still responsible for learning how to operate, monitor, backup, upgrade, etc. the Vault cluster.%b\n" "${RED}" "${NC}"

  printf "\nDo you understand?\n"

  select vault in "Yes" "No"; do
        case $vault in
            Yes ) echo "Installing Hashicorp Vault. NOTE: The values files to overwrite the settings can be found at bootstrap/vault/overwrite-values.yaml"; install_vault; break;;
            No) echo "Exiting"; exit;;
        esac
  done 

}

function install_vault() {

  printf "\n%bDeploy Hashicorp Vault%b\n" "${RED}" "${NC}"
  $HELM repo add hashicorp https://helm.releases.hashicorp.com
  $HELM repo update
  $HELM upgrade --install vault hashicorp/vault --values bootstrap/vault/overwrite-values.yaml --namespace=vault --create-namespace
}

$KUSTOMIZE >/dev/null 2>&1 || error "Could not execute kustomize binary!"
$HELM >/dev/null 2>&1 || error "Could not execute helm binary!"

printf "\nDo you wish to continue and install GitOps?\n\n"
printf "Press 1 or 2\n"
select yn in "Yes" "No" "Skip"; do
    case $yn in
        Yes ) echo "Starting Deployment"; deploy; break;;
        No ) echo "Exit"; exit;;
        Skip) echo -e "${RED}Skip deployment of GitOps and continue with Secret Management${NC}"; verify_secret_mgmt; break;;
    esac
done

