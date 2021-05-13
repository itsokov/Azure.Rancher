
# - EXECUTE ON RANCHER - 

#injectable secrets external vault

helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

helm install vault hashicorp/vault \
    --set "injector.externalVaultAddr=http://10.0.2.4:8200"

 kubectl get pods
 kubectl describe serviceaccount vault
 apt install jq -y

 VAULT_HELM_SECRET_NAME=$(kubectl get secrets --output=json | jq -r '.items[].metadata | select(.name|startswith("vault-token-")).name')


 ####install vault to use as client

curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install vault
export VAULT_ADDR=http://10.0.2.4:8200

vault unseal
vault login
vault auth enable kubernetes
vault secrets enable -path=secret/ kv
vault kv put secret/devwebapp/config username='giraffe' password='salsa'

TOKEN_REVIEW_JWT=$(kubectl get secret $VAULT_HELM_SECRET_NAME --output='go-template={{ .data.token }}' | base64 --decode)
KUBE_CA_CERT=$(kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.certificate-authority-data}' | base64 --decode)
KUBE_HOST=$(kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.server}')


vault write auth/kubernetes/config \
        token_reviewer_jwt="$TOKEN_REVIEW_JWT" \
        kubernetes_host="$KUBE_HOST" \
        kubernetes_ca_cert="$KUBE_CA_CERT"


vault policy write devwebapp - <<EOF
path "secret/*" {
  capabilities = ["read"]
}
EOF

vault write auth/kubernetes/role/devweb-app \
        bound_service_account_names=internal-app \
        bound_service_account_namespaces=default \
        policies=devwebapp \
        ttl=24h



cat > devwebapp.yaml <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: devwebapp
  labels:
    app: devwebapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: devwebapp
  template:
    metadata:
      labels:
        app: devwebapp
    spec:
      serviceAccountName: internal-app
      containers:
      - name: app
        image: burtlo/devwebapp-ruby:k8s
        imagePullPolicy: Always

EOF

cat > patch-02-inject-secrets.yml <<EOF
spec:
  template:
    metadata:
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "devweb-app"
        vault.hashicorp.com/agent-inject-secret-credentials.txt: "secret/devwebapp/config"
EOF   

cat > internal-app.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: internal-app
EOF

kubectl apply --filename internal-app.yaml

kubectl apply --filename devwebapp.yaml
kubectl patch deployment devwebapp --patch "$(cat patch-02-inject-secrets.yml)"

kubectl exec -it \
    $(kubectl get pod --selector='app=devwebapp' --output='jsonpath={.items[0].metadata.name}') \
    -c app -- cat /vault/secrets/credentials.txt





# vault agent https://learn.hashicorp.com/tutorials/vault/agent-kubernetes?in=vault/kubernetes

 ####install vault to use as client

curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install vault
export VAULT_ADDR=http://10.0.2.4:8200

vault operator unseal
vault login
vault secrets enable -path=secret/ kv



cat > vault-auth-service-account.yaml <<EOF
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: role-tokenreview-binding
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: vault-auth
  namespace: default
EOF

kubectl create serviceaccount vault-auth
kubectl apply --filename vault-auth-service-account.yaml

vault policy write myapp-kv-ro - <<EOF
path "secret/*" {
    capabilities = ["read", "list"]
}
EOF
vault kv put secret/myapp/config username='appuser' \
        password='suP3rsec(et!' \
        ttl='30s'

export VAULT_SA_NAME=$(kubectl get sa vault-auth \
    -o jsonpath="{.secrets[*]['name']}")
export SA_JWT_TOKEN=$(kubectl get secret $VAULT_SA_NAME \
    -o jsonpath="{.data.token}" | base64 --decode; echo)
export SA_CA_CRT=$(kubectl get secret $VAULT_SA_NAME \
    -o jsonpath="{.data['ca\.crt']}" | base64 --decode; echo)
export K8S_HOST=$(kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.server}')

vault auth enable kubernetes

vault write auth/kubernetes/config \
        token_reviewer_jwt="$SA_JWT_TOKEN" \
        kubernetes_host="$K8S_HOST" \
        kubernetes_ca_cert="$SA_CA_CRT"

vault write auth/kubernetes/role/example \
        bound_service_account_names=vault-auth \
        bound_service_account_namespaces=default \
        policies=myapp-kv-ro \
        ttl=24h

EXTERNAL_VAULT_ADDR="http://10.0.2.4:8200"

cat > configmap.yaml <<EOF
apiVersion: v1
data:
  vault-agent-config.hcl: |
    # Comment this out if running as sidecar instead of initContainer
    exit_after_auth = true

    pid_file = "/home/vault/pidfile"

    auto_auth {
        method "kubernetes" {
            mount_path = "auth/kubernetes"
            config = {
                role = "example"
            }
        }

        sink "file" {
            config = {
                path = "/home/vault/.vault-token"
            }
        }
    }

    template {
    destination = "/etc/secrets/index.html"
    contents = <<EOT
    <html>
    <body>
    <p>Some secrets:</p>
    {{- with secret "secret/myapp/config" }}
    <ul>
    <li><pre>username: {{ .Data.username }}</pre></li>
    <li><pre>password: {{ .Data.password }}</pre></li>
    </ul>
    {{ end }}
    </body>
    </html>
    EOT
    }
kind: ConfigMap
metadata:
  name: example-vault-agent-config
  namespace: default
EOF

kubectl create -f configmap.yaml
kubectl get configmap example-vault-agent-config -o yaml


cat > example-k8s-spec.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: vault-agent-example
  namespace: default
spec:
  serviceAccountName: vault-auth

  volumes:
  - configMap:
      items:
      - key: vault-agent-config.hcl
        path: vault-agent-config.hcl
      name: example-vault-agent-config
    name: config
  - emptyDir: {}
    name: shared-data

  initContainers:
  - args:
    - agent
    - -config=/etc/vault/vault-agent-config.hcl
    - -log-level=debug
    env:
    - name: VAULT_ADDR
      value: http://10.0.2.4:8200
    image: vault
    name: vault-agent
    volumeMounts:
    - mountPath: /etc/vault
      name: config
    - mountPath: /etc/secrets
      name: shared-data

  containers:
  - image: nginx
    name: nginx-container
    ports:
    - containerPort: 80
    volumeMounts:
    - mountPath: /usr/share/nginx/html
      name: shared-data
EOF

kubectl apply -f example-k8s-spec.yaml --record

kubectl port-forward pod/vault-agent-example 8080:80

curl localhost:8080 



## do the same thing for an app once the kubernetes-vault trust has been established with the vault-auth account



kubectl create serviceaccount vault-auth2

vault policy write myapp-kv-ro2 - <<EOF
path "secret/*" {
    capabilities = ["read", "list"]
}
EOF


vault auth enable kubernetes


vault write auth/kubernetes/role/example2 \
        bound_service_account_names=vault-auth2 \
        bound_service_account_namespaces=default \
        policies=myapp-kv-ro2 \
        ttl=24h

EXTERNAL_VAULT_ADDR="http://10.0.2.4:8200"

cat > configmap.yaml <<EOF
apiVersion: v1
data:
  vault-agent-config.hcl: |
    # Comment this out if running as sidecar instead of initContainer
    exit_after_auth = true

    pid_file = "/home/vault/pidfile"

    auto_auth {
        method "kubernetes" {
            mount_path = "auth/kubernetes"
            config = {
                role = "example2"
            }
        }

        sink "file" {
            config = {
                path = "/home/vault/.vault-token"
            }
        }
    }

    template {
    destination = "/etc/secrets/index.html"
    contents = <<EOT
    <html>
    <body>
    <p>Some secrets:</p>
    {{- with secret "secret/myapp/config" }}
    <ul>
    <li><pre>username: {{ .Data.username }}</pre></li>
    <li><pre>password: {{ .Data.password }}</pre></li>
    </ul>
    {{ end }}
    </body>
    </html>
    EOT
    }
kind: ConfigMap
metadata:
  name: example2-vault-agent-config
  namespace: default
EOF

kubectl create -f configmap.yaml
kubectl get configmap example2-vault-agent-config -o yaml


cat > example2-k8s-spec.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: vault-agent-example2
  namespace: default
spec:
  serviceAccountName: vault-auth2

  volumes:
  - configMap:
      items:
      - key: vault-agent-config.hcl
        path: vault-agent-config.hcl
      name: example2-vault-agent-config
    name: config
  - emptyDir: {}
    name: shared-data

  initContainers:
  - args:
    - agent
    - -config=/etc/vault/vault-agent-config.hcl
    - -log-level=debug
    env:
    - name: VAULT_ADDR
      value: http://10.0.2.4:8200
    image: vault
    name: vault-agent
    volumeMounts:
    - mountPath: /etc/vault
      name: config
    - mountPath: /etc/secrets
      name: shared-data

  containers:
  - image: nginx
    name: nginx-container
    ports:
    - containerPort: 80
    volumeMounts:
    - mountPath: /usr/share/nginx/html
      name: shared-data
EOF

kubectl apply -f example2-k8s-spec.yaml --record

kubectl port-forward pod/vault-agent-example2 8080:80

curl localhost:8080 



#### test area

cat > memory-defaults.yaml <<EOF 
apiVersion: v1
kind: LimitRange
metadata:
  name: mem-limit-range
spec:
  limits:
  - default:
      memory: 512Mi
    defaultRequest:
      memory: 256Mi
    type: Container
EOF


kubectl apply -f memory-defaults.yaml --namespace=default



#### test area2

cat > example-k8s-spec.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: vault-agent-example
  namespace: default
spec:
  serviceAccountName: vault-auth

  volumes:
  - configMap:
      items:
      - key: vault-agent-config.hcl
        path: vault-agent-config.hcl
      name: example-vault-agent-config
    name: config
  - emptyDir: {}
    name: shared-data

  initContainers:
  - args:
    - agent
    - -config=/etc/vault/vault-agent-config.hcl
    - -log-level=debug
    env:
    - name: VAULT_ADDR
      value: http://10.0.2.4:8200
    image: vault
    name: vault-agent
    volumeMounts:
    - mountPath: /etc/vault
      name: config
    - mountPath: /etc/secrets
      name: shared-data

  containers:
  - image: nginx
    name: nginx-container
    resources:
      limits:
        memory: "1Gi"
    ports:
    - containerPort: 80
    volumeMounts:
    - mountPath: /usr/share/nginx/html
      name: shared-data
EOF

kubectl apply -f example-k8s-spec.yaml --record
