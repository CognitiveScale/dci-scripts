#!/usr/bin/env bash

RETRIES=10 # TODO revisit this retry count
# Change IFS to new line.
IFS=$'\n'

#sleep 10 # TODO make this less static and perform status check w/ backoff
podID=$(kubectl get pods -n cortex -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' | grep 'cortex-accounts')
acct_jwt_god_token=$(kubectl exec -n cortex -i "${podID}" -- bash -c "node /app/generate-god-jwt-for-docker.js")
# obtain the list of action containers
actionString=$(kubectl get pods -n cortex -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' | grep 'cortex-actions')
# convert new line to arrays
actionList=($actionString)

# begin login for actions
for ((i = 0; i < ${#actionList[@]}; i++)); do
    if [ $i -eq 0 ]; then
      CORTEX_FQDN=$(kubectl exec -n cortex -i "${actionList[$i]}" -- bash -c "echo \$DOCKER_PRIVATE_REPO")
    fi
    NEXT_WAIT_TIME=0
    until kubectl exec -n cortex -i "${actionList[$i]}" -- bash -c "docker login $CORTEX_FQDN -u=cortex5kube -p=\"$acct_jwt_god_token\""; do
        echo "create_admin_token_register_services-actions: Waiting for docker login to private-registry..." && sleep $((NEXT_WAIT_TIME++))
        if [ $NEXT_WAIT_TIME -gt $RETRIES ]; then
            echo "create_admin_token_register_services-actions: max retries hit..." && exit 1
        fi
    done

    if [ $i -eq 0 ]; then
        # update secrets for k8s
        docker_secrets_config_actions=$(kubectl exec -i -n cortex "${actionList[$i]}" -- bash -c 'cat ~/.docker/config.json')
        docker_secrets_config_actions_no_newline=$(echo -n "$docker_secrets_config_actions" | jq -c '.')
        docker_secrets_config_base64=$(echo -n "$docker_secrets_config_actions_no_newline" | base64)
        docker_secrets_config_actions_no_newline_escaped=$(echo "$docker_secrets_config_actions_no_newline" | sed -E 's/([(){}"/:.]){1}/\\\1/g')
        kubectl get secret -n cortex docker-login -o json | jq --arg updated_value "$docker_secrets_config_base64" '.data[".dockerconfigjson"]=$updated_value' | kubectl apply -f -
        kubectl get secret -n cortex-compute docker-login -o json | jq --arg updated_value "$docker_secrets_config_base64" '.data[".dockerconfigjson"]=$updated_value' | kubectl apply -f -
    fi
done
