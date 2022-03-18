#!/bin/bash
set -euf -o pipefail
RED='\033[0;31m'
NC='\033[0m' # No Color


OPT_DRY_RUN='false'
HELM="/usr/bin/env helm"

while getopts ':d:o:h' 'OPTKEY'; do
    case ${OPTKEY} in
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

function error() {
    echo "$1"
    exit 1
}

# Deploy Hashicorp Vault if selected
function deploy() {

  $HELM 2>&1 >/dev/null || error "Could not execute helm binary!"

  printf "\nThis will create an '\(ArgoCD\) Application of Applications' which then automatically creates ArgoCD objects like ApplicationSets ad Application\n"
  echo -e "Sleeping 3 seconds ... if you change your mind :)"
  sleep 3

  $HELM upgrade --install --values ./bootstrap/init_app_of_apps/values.yaml --namespace=openshift-gitops app-of-apps ./bootstrap/init_app_of_apps

}

deploy

