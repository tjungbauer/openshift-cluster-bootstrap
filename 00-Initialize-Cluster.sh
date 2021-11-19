#!/bin/bash
set -euf -o pipefail
RED='\033[0;31m'
NC='\033[0m' # No Color


OPT_DRY_RUN='false'
OVERLAY='default'
KUSTOMIZE="/usr/bin/env kustomize"

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

function deploy() {
  $KUSTOMIZE 2>&1 >/dev/null || error "Could not execute kustomize binary!"

  printf "\n${RED}Deploy GITOPS${NC}\n"
  $KUSTOMIZE build bootstrap/openshift-gitops/overlays/"$OVERLAY" | oc apply $DRY_RUN -f -

  printf "\n${RED}Deploy Selaed Secrets${NC}\n"
  $KUSTOMIZE build bootstrap/sealed-secrets/base | oc apply $DRY_RUN -f - 
}

if [ "$OVERLAY" == "default" ]; then

    cat<<EOF
This will bootstrap the GitOps operator with the "$OVERLAY" overlay.
If this is not what you want you can specify a different overlay via
$0 <overlay name>
EOF

    echo -e "Currently this repo supports the following overlays:\n"
    ls -1 bootstrap/openshift-gitops/overlays/

    echo -e "\nHit CTRL+C now to specify a different overlay than '$OVERLAY'"
    echo -e "Sleeping 10 seconds"
    sleep 10
fi

deploy