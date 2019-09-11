#!/bin/bash -eux

# Usage:
#   ./construct-registry-auth.sh kubectl cortex-docker-login
#

COMMAND=${1:-kubectl}    # should be able to use kubectl or oc
DOCKER_SECRET_NAME=${2:-docker-login}

USER=cortex
podID=$($COMMAND get pods -n cortex -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' | grep 'cortex-accounts')
PASSWORD=$($COMMAND exec -n cortex -i "${podID}" -- bash -c "node /app/generate-god-jwt-for-docker.js")

# obtain the list of action containers
kongString=$($COMMAND get pods -n cortex -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' | grep 'cortex-kong')
# convert new line to arrays
kongList=($kongString)
REPOURL=private-registry.$($COMMAND exec -n cortex -i "${kongList[0]}" -- bash -c "echo \$CORTEX_BASE_DOMAIN")

BASE64AUTH=$(echo -n "$USER:$PASSWORD" | base64)

if [[ -z "$(kubectl get secrets -n cortex | grep $DOCKER_SECRET_NAME)" ]]; then
  #Create new
  echo "{\"auths\":{\"$REPOURL\":{\"auth\":\"$BASE64AUTH\"}}}" > dockersecret.json
  $COMMAND create secret generic $DOCKER_SECRET_NAME --from-file=.dockerconfigjson=dockersecret.json --type=kubernetes.io/dockerconfigjson --namespace cortex
  $COMMAND create secret generic $DOCKER_SECRET_NAME --from-file=.dockerconfigjson=dockersecret.json --type=kubernetes.io/dockerconfigjson --namespace cortex-compute
else
  ##Replace existing
  # NOTE `base64 -d` is not portable between mac and linux
  EXISTINGSECRET=$($COMMAND get secret -n cortex $DOCKER_SECRET_NAME -o jsonpath="{.data['\.dockerconfigjson']}" | base64 --decode)
  UPDATEDSECRET=$(echo -n $EXISTINGSECRET | jq -c ".auths.\"$REPOURL\"={\"auth\":\"$BASE64AUTH\"}")
  DOCKERCONFIG64=$(echo -n $UPDATEDSECRET  | base64)
  $COMMAND get secret -n cortex $DOCKER_SECRET_NAME -o json | jq --arg updated_value "$DOCKERCONFIG64" '.data[".dockerconfigjson"]=$updated_value' | $COMMAND apply -f -
  $COMMAND get secret -n cortex-compute $DOCKER_SECRET_NAME -o json | jq --arg updated_value "$DOCKERCONFIG64" '.data[".dockerconfigjson"]=$updated_value' | $COMMAND apply -f -
fi
