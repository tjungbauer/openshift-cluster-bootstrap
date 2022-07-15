              #!/usr/bin/env bash
              # Wait for central to be ready
              attempt_counter=0
              max_attempts=20
              
              echo "Waiting for operator to be available..."

              # we assume that the operator is ready, once the CRD Central is available.
              # when this is the case ArgoCD can continue
              until $(oc get crd/centrals.platform.stackrox.io2 &>/dev/null); do
                  if [ ${attempt_counter} -eq ${max_attempts} ];then
                    echo "Max attempts reached. I give up"
                    exit 1
                  fi
                  attempt_counter=$(($attempt_counter+1))
                  echo "Made attempt $attempt_counter of $max_attempts, waiting..."
                  sleep 5
              done

              echo "Operator seeme to be ready"
