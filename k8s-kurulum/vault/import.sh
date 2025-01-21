#/bin/bash
VAULT_TOKEN=ixxxxxxxxxxxxxxxxxxxxxxxxxxxxxxD
KEY1=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
KEY2=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
KEY3=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

#sed -i 's/abc.com.tr/dfg.com.tr/g' exports/*json

kubectl exec -it -n vault vault-0 -c vault -- sh -c \
"vault operator unseal $KEY1 && \
vault operator unseal $KEY2 && \
vault operator unseal $KEY3  "

kubectl exec -it -n vault vault-1 -c vault -- sh -c \
"vault operator raft join http://vault-0.vault-internal:8200 && \
vault operator unseal $KEY1 && \
vault operator unseal $KEY2 && \
vault operator unseal $KEY3"

kubectl exec -it -n vault vault-2 -c vault -- sh -c \
"vault operator raft join http://vault-0.vault-internal:8200 && \
vault operator unseal $KEY1 && \
vault operator unseal $KEY2 && \
vault operator unseal $KEY3 "		

kubectl cp policies -n vault vault-0:/tmp/
kubectl cp exports -n vault vault-0:/tmp/
kubectl exec -it -n vault vault-0 -c vault -- sh -c \
"export VAULT_TOKEN=$VAULT_TOKEN && \
vault auth enable approle && \ 
vault auth enable kubernetes"

kubectl exec -it -n vault vault-0 -c vault -- sh -c \
"export VAULT_TOKEN=$VAULT_TOKEN && \
vault secrets enable -path=yazılım/android --version=2 kv"

kubectl exec -it -n vault vault-0 -c vault -- sh -c \
"export VAULT_TOKEN=$VAULT_TOKEN && \
vault write auth/kubernetes/config kubernetes_host=https://10.233.0.1:443 && \
vault write auth/kubernetes/role/yazılım-android-dev bound_service_account_names=yazılım-android-dev bound_service_account_namespaces=yazılım-android-dev policies=yazılım-android-dev ttl=0 && \
vault policy write yazılım-android-dev /tmp/policies/yazılım-android-dev  && \
vault policy write android2020-system /tmp/policies/android2020-system"

kubectl exec -it -n vault vault-0 -c vault -- sh -c \
	"export VAULT_TOKEN=$VAULT_TOKEN && \
	vault write auth/approle/role/yazılım-android-dev token_policies=yazılım-android-dev token_ttl=2m token_max_ttl=3m"

roleid=$(kubectl exec -it -n vault vault-0 -c vault -- sh -c \
	"export VAULT_TOKEN=$VAULT_TOKEN && \
	vault read auth/approle/role/yazılım-android-dev/role-id" | grep role_id | awk '{print $NF}'|sed 's/[^a-zA-Z0-9 ]//g')

secretid=$(kubectl exec -it -n vault vault-0 -c vault -- sh -c \
	"export VAULT_TOKEN=$VAULT_TOKEN && \
	vault write -force auth/approle/role/yazılım-android-dev/secret-id" | grep -v secret_id_a | grep -v secret_id_t | grep -v secret_id_n | awk '{print $NF}'| sed 's/ //g')

secretid=$(echo $secretid | awk '{print $NF}' | sed 's/[^a-zA-Z0-9 ]//g')

sed -i '/VAULT_ROLE_ID/d' exports/config_configuration
sed -i '/VAULT_SECRET_ID/d' exports/config_configuration
sed -i '/}/d' exports/config_configuration
echo '  "VAULT_ROLE_ID": "'$roleid'",' 		>> exports/config_configuration
echo '  "VAULT_ROLE_ID": "'$secretid'"' 	>> exports/config_configuration
echo "}" 			 		>> exports/config_configuration

kubectl exec -it -n vault vault-0 -c vault -- sh -c \
"export VAULT_TOKEN=$VAULT_TOKEN && \
for line in \$(ls /tmp/exports); do \
  vault kv put yazılım/android/dev/\$line @/tmp/exports/\$line; \
done"

