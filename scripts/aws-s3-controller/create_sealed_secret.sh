#secret.txt should contain
#AWS_ACCESS_KEY_ID=
#AWS_SECRET_ACCESS_KEY=

oc create secret generic ack-s3-user-secrets --dry-run=client --from-env-file=<PATH_TO_YOUR>/secrets.txt -o yaml -n ack-system \
| kubeseal --controller-namespace=sealed-secrets --controller-name=sealed-secrets --format yaml  > ../../clusters/all/aws-controller-s3/templates/ack-s3-user-secrets.yaml
