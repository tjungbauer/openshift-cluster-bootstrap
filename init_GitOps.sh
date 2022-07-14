#!/bin/bash
set -euf -o pipefail
RED='\033[37;41m'  # White text with red background
CYAN_BG='\033[30;46m' # Black text with cyan background
NC='\033[0m' # No Color
TIMER=45 # Sleep timer to initially wait for the gitops-operator to be deployed before starting testing the deployments. 

OPT_DRY_RUN='false'
SECRET_MGMT=''
OVERLAY='default'
KUSTOMIZE="/usr/bin/env kustomize"
HELM="/usr/bin/env helm"

function showhelp() {
    cat <<EOF
Be sure to define at least the command line option -o

The following options are known:

  -o ... Defines the OVERLAY. (i.e. -o default)
  -d ... Defines if DRY RUN is used or not (i.e. -d=false)
EOF

    exit 1
}

while getopts ':d:o:h' 'OPTKEY'; do
    case ${OPTKEY} in
        'd')
            OPT_DRY_RUN='true'
            ;;
        's')
            SECRET_MGMT=''
            ;;
        'o')
            OVERLAY=${OPTARG}
            ;;
        'h')
            showhelp
            ;;
        '?')
            echo "INVALID OPTION -- ${OPTARG}" >&2
            exit 1
            ;;
        ':')
            echo "MISSING ARGUMENT for option -- ${OPTARG}" >&2
            exit 1
            ;;
        *)
            echo "UNIMPLEMENTED OPTION -- ${OPTKEY}" >&2
            exit 1
            ;;
    esac
done


if ${OPT_DRY_RUN}; then
    printf "${RED}DRY RUN is enabled !!!${NC}\n"
    DRY_RUN="--dry-run=client"
else
    DRY_RUN=""
fi

function error() {
    echo "$1"
    exit 1
}

# Get available overlays for openshift-gitops deployment
function get_available_overlays() {
    ls -1 bootstrap/openshift-gitops/overlays/
}

# Ask which Secret Manager should be installed
function verify_secret_mgmt() {
  printf "\nPlease select one of the supported Secrets Manager.\n\n"
  printf "Press 1, 2, 3\n"
  select svn in "Sealed-Secrets" "Hashicorp-Vault" "None"; do
        case $svn in
            Sealed-Secrets ) echo -e "Installing Sealed Secrets"; install_sealed_secrets; break;;
            Hashicorp-Vault) echo "Installing Hashicorp Vault"; starting_vault; break;;
            None) echo "Using NO Secret Manager. Exiting"; exit;; 
        esac
    done  
}

# Deploy openshift-gitops
function deploy() {
  printf "\n${RED}Deploy GITOPS${NC}\n"
  $KUSTOMIZE build bootstrap/openshift-gitops/overlays/"${OVERLAY}" | oc apply $DRY_RUN -f -

  printf "\nGive the gitops-operator some time to be installed. ${RED}Waiting for $TIMER seconds...${NC}\n"
  sleep $TIMER

  printf "\n${RED}Waiting for operator to start. Chcking every 5 seconds.${NC}\n"
  until oc get deployment gitops-operator-controller-manager -n openshift-operators
  do
    sleep 5;
  done

  printf "\n${RED}Waiting for openshift-gitops namespace to be created. Chcking every 5 seconds.${NC}\n"
  until oc get ns openshift-gitops
  do
    sleep 5;
  done

  printf "\n${RED}Waiting for deployments to start. Chcking every 5 seconds.${NC}\n"
  until oc get deployment cluster -n openshift-gitops
  do
    sleep 5;
  done

  echo "Waiting for all pods to be created"
  deployments=(cluster kam openshift-gitops-applicationset-controller openshift-gitops-redis openshift-gitops-repo-server openshift-gitops-server)
  for i in "${deployments[@]}";
  do
    printf "\n${CYAN_BG}Waiting for deployment $i ${NC}\n";
    oc rollout status deployment $i -n openshift-gitops
  done

  echo "GitOps Operator ready"

  deploy_app_of_apps

  verify_secret_mgmt
}

function deploy_app_of_apps() {

  $HELM 2>&1 >/dev/null || error "Could not execute helm binary!"

  printf "\n${RED}Deploy ArgoCD Application of Applications${NC}\n"
  printf "This will create an ArgoCD Application of Applications which then automatically creates ArgoCD objects like ApplicationSets ad Application\n"

  $HELM upgrade --install --values ./bootstrap/init_app_of_apps/values.yaml --namespace=openshift-gitops app-of-apps ./bootstrap/init_app_of_apps

}

# Deploy Sealed Secrets if selected
function install_sealed_secrets() {
  printf "\n${RED}Deploy Selaed Secrets${NC}\n"
  $KUSTOMIZE build bootstrap/sealed-secrets/base | oc apply $DRY_RUN -f - 
}

# Deploy Hashicorp Vault if selected
function starting_vault() {

  $HELM 2>&1 >/dev/null || error "Could not execute helm binary!"

  printf "\nWhile the Helm chart automatically sets up complex resources and exposes the configuration to meet your requirements, 
it does not automatically operate Vault. ${RED}You are still responsible for learning how to operate, monitor, backup, upgrade, etc. the Vault cluster.${NC}\n"

  printf "\nDo you understand?\n"

  select vault in "Yes" "No"; do
        case $vault in
            Yes ) echo -e "Installing Hashicorp Vault. NOTE: The values files to overwrite the settings can be found at bootstrap/vault/overwrite-values.yaml"; install_vault; break;;
            No) echo "Exiting"; exit;;
        esac
  done 

}

function install_vault() {

  printf "\n${RED}Deploy Hashicorp Vault${NC}\n"
  $HELM repo add hashicorp https://helm.releases.hashicorp.com
  $HELM repo update
  $HELM upgrade --install vault hashicorp/vault --values bootstrap/vault/overwrite-values.yaml --namespace=vault --create-namespace
}

$KUSTOMIZE 2>&1 >/dev/null || error "Could not execute kustomize binary!"

printf "This will bootstrap the GitOps operator with the ${RED}${OVERLAY}${NC} overlay.
If this is not what you want you can specify a different overlay via
$0 -o <overlay name>\n\n"

printf "Currently this repo supports the following overlays:\n"
get_available_overlays
    
printf "\nDo you wish to continue and install GitOps using the ${RED}${OVERLAY}${NC} settings?\n\n"
printf "Press 1 or 2\n"
select yn in "Yes" "No" "Skip"; do
    case $yn in
        Yes ) echo -e "Starting Deployment"; deploy; break;;
        No ) echo "Exit"; exit;;
        Skip) echo -e "${RED}Skip deployment of GitOps and continue with Secret Management${NC}"; verify_secret_mgmt; break;;
    esac
done

