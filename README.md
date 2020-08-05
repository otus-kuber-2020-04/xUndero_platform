# xUndero_platform
xUndero Platform repository

## ДЗ 10 Vault+k8s
1. ### Установка и начало работы с Vault:
  * После установки:
  ```
  helm status vault -n vault
  NAME: vault
  LAST DEPLOYED: Sun Jul 26 18:38:20 2020
  NAMESPACE: vault
  STATUS: deployed
  REVISION: 1
  TEST SUITE: None
  NOTES:
  Thank you for installing HashiCorp Vault!

  kubectl -n vault logs vault-0
  ...
  2020-07-26T13:39:05.302Z [INFO]  core: seal configuration missing, not initialized
  2020-07-26T13:39:08.324Z [INFO]  core: seal configuration missing, not initialized
  ```
  * После инициализации:
  ```
  kubectl -n vault exec -it vault-0 -- vault operator init --key-shares=1 --key-threshold=1
  Unseal Key 1: KiKaWg7/u/CzEUAJH+GpJFFSGwUjwZiS1ngKKfXEDHA=

  Initial Root Token: s.ogbEXKYwcfhJp6mUREXZK3nu
  ```
  * После unseal:
  ```
  kubectl -n vault exec -it vault-2 -- vault status
  Key             Value
  ---             -----
  Seal Type       shamir
  Initialized     true
  Sealed          false
  Total Shares    1
  Threshold       1
  Version         1.4.2
  Cluster Name    vault-cluster-3e4c4917
  Cluster ID      cea5c402-5bb1-0892-6426-e1f598c2ac92
  HA Enabled      true
  HA Cluster      https://vault-2.vault-internal:8201
  HA Mode         active
  ```
  * 
  ```
  kubectl -n vault exec -it vault-0 -- vault login    
  Token (will be hidden): 
  Success! You are now authenticated. The token information displayed below
  is already stored in the token helper. You do NOT need to run "vault login"
  again. Future Vault requests will automatically use this token.

  Key                  Value
  ---                  -----
  token                s.ogbEXKYwcfhJp6mUREXZK3nu
  token_accessor       I7TEApkyL8qw6U76FmfvY4Pm
  token_duration       ∞
  token_renewable      false
  token_policies       ["root"]
  identity_policies    []
  policies             ["root"]
  ```
  * 
  ```
  kubectl -n vault exec -it vault-0 -- vault auth list
  Path      Type     Accessor               Description
  ----      ----     --------               -----------
  token/    token    auth_token_76ad9a0f    token based credentials
  ```
  * 
  ```
  kubectl -n vault exec -it vault-0 -- vault read otus/otus-ro/config                                
  Key                 Value
  ---                 -----
  refresh_interval    768h
  password            asajkjkahs
  username            otus
  ```

2. ### Авторизация через k8s:
  * Включим авторизацию k8s:
  ```
  kubectl -n vault exec -it vault-0 -- vault auth list
  Path           Type          Accessor                    Description
  ----           ----          --------                    -----------
  kubernetes/    kubernetes    auth_kubernetes_da05e5da    n/a
  token/         token         auth_token_76ad9a0f         token based credentials
  ```
    Для получения переменной K8S_HOST использовался путь через cluster-info,  
    т. к. в файле config содержится информация о нескольких кластерах;  
  * Ошибка записи возникла потому, что в политике разрешено создавать но не разрешено изменять  
    Для исправления следует добавить в политику способность "update";

3. ### CA на базе Vault:
  ```
  kubectl -n vault exec -it vault-0 -- vault write pki_int/issue/devlab-dot-ru common_name="gitlab.devlab.ru" ttl="24h"
  Error writing data to pki_int/issue/devlab-dot-ru: Error making API request.

  URL: PUT http://127.0.0.1:8200/v1/pki_int/issue/devlab-dot-ru
  Code: 400. Errors:

  unknown role: devlab-dot-ru
  command terminated with exit code 2
  ```
  ```
  kubectl -n vault exec -it vault-0 -- vault write pki_int/issue/example-dot-ru common_name="gitlab.example.ru" ttl="24h"
  Key                 Value
  ---                 -----
  ca_chain            [-----BEGIN CERTIFICATE-----
  MIIDnDCCAoSgAwIBAgIUOoq1xhUSbqFKAqVjuWSd4UMZfUkwDQYJKoZIhvcNAQEL
  ...
  gyadYMMugFrrltn/CA01hA==
  -----END CERTIFICATE-----]
  certificate         -----BEGIN CERTIFICATE-----
  MIIDZzCCAk+gAwIBAgIUdzHb72RczmdT6PA5glAyQfT6yb8wDQYJKoZIhvcNAQEL
  ...
  OJQTH0V5dpDqFGI=
  -----END CERTIFICATE-----
  expiration          1596032425
  issuing_ca          -----BEGIN CERTIFICATE-----
  MIIDnDCCAoSgAwIBAgIUOoq1xhUSbqFKAqVjuWSd4UMZfUkwDQYJKoZIhvcNAQEL
  gyadYMMugFrrltn/CA01hA==
  -----END CERTIFICATE-----
  private_key         -----BEGIN RSA PRIVATE KEY-----
  MIIEowIBAAKCAQEAzL6r7xPw/SPq9nr9Zj1//REgY2c788o+XdjTJBhTmC7ycCfF
  ...
  3GkeEk5d8f7KNPGMb02b2TqjueiSICFll+XeDXMfFjmGs4h8yH90
  -----END RSA PRIVATE KEY-----
  private_key_type    rsa
  serial_number       77:31:db:ef:64:5c:ce:67:53:e8:f0:39:82:50:32:41:f4:fa:c9:bf
  ```
  * Для включения TLS генерим закрытый ключ:  
    *`openssl genrsa -out vault.key 2048`*
    затем создаём запрос на сертификат:  
    *`openssl req -config ./vault_gke_csr.cnf -new -key ./vault.key -nodes -out vault.csr`*  
    помещаем запрос в кубер:  
    ```
    cat <<EOF | kubectl apply -f -
    apiVersion: certificates.k8s.io/v1beta1
    kind: CertificateSigningRequest
    metadata:
      name: vault.vault
    spec:
      request: $(cat vault.csr | base64 | tr -d '\n')
      usages:
      - digital signature
      - key encipherment
      - server auth
    EOF    
    ```
    и подтверждаем его:  
    *`kubectl certificate approve vault.vault`*  
    после достаём сертификат:  
    *`kubectl get csr vault.vault -o jsonpath='{.status.certificate}' | base64 --decode > vault.crt`*
    и создаём secret tls:  
    *`kubectl -n vault create secret tls vault-certs --cert=./vault.crt --key=./vault.key`*  
  * Включение автообновления сертификата в каталоге ./web  
    И сертификаты:
  ![CERT1](https://raw.githubusercontent.com/otus-kuber-2020-04/xUndero_platform/kubernetes-vault/kubernetes-vault/cert1.png)
  ![CERT2](https://raw.githubusercontent.com/otus-kuber-2020-04/xUndero_platform/kubernetes-vault/kubernetes-vault/cert2.png)

## ДЗ 9 Сервисы централизованного логирования для компонентов Kubernetes и приложений
1. ### Подготовка кластера и приложения:
  * Кластер создан с помощью terraform;
  * Приложение запущено:
  ```
  kubectl get pods -n microservices-demo -o wide
  NAME                                     READY   STATUS    RESTARTS   AGE     IP           NODE                                        NOMINATED NODE   READINESS GATES
  adservice-9679d5b56-zkkr5                1/1     Running   0          2m38s   10.48.0.19   gke-my-cluster-default-pool-ded1b785-wvq8   <none>           <none>
  cartservice-66b4c7d59-dvkn8              1/1     Running   2          2m44s   10.48.0.14   gke-my-cluster-default-pool-ded1b785-wvq8   <none>           <none>
  checkoutservice-6cb96b65fd-8xtvv         1/1     Running   0          2m51s   10.48.0.9    gke-my-cluster-default-pool-ded1b785-wvq8   <none>           <none>
  currencyservice-68df8c8788-fxmtb         1/1     Running   0          2m42s   10.48.0.16   gke-my-cluster-default-pool-ded1b785-wvq8   <none>           <none>
  emailservice-6fc9c98fd-wsxb5             1/1     Running   0          2m52s   10.48.0.8    gke-my-cluster-default-pool-ded1b785-wvq8   <none>           <none>
  frontend-5559967bcd-swt47                1/1     Running   0          2m48s   10.48.0.11   gke-my-cluster-default-pool-ded1b785-wvq8   <none>           <none>
  loadgenerator-674846f899-zlmjv           1/1     Running   4          2m43s   10.48.0.15   gke-my-cluster-default-pool-ded1b785-wvq8   <none>           <none>
  paymentservice-6cb4db7678-ghs6k          1/1     Running   0          2m46s   10.48.0.12   gke-my-cluster-default-pool-ded1b785-wvq8   <none>           <none>
  productcatalogservice-768b67d968-nxvh9   1/1     Running   0          2m45s   10.48.0.13   gke-my-cluster-default-pool-ded1b785-wvq8   <none>           <none>
  recommendationservice-f45c4979d-l7sdc    1/1     Running   0          2m49s   10.48.0.10   gke-my-cluster-default-pool-ded1b785-wvq8   <none>           <none>
  redis-cart-cfcbcdf6c-drr64               1/1     Running   0          2m40s   10.48.0.18   gke-my-cluster-default-pool-ded1b785-wvq8   <none>           <none>
  shippingservice-5d68c4f8d4-96sx6         1/1     Running   0          2m41s   10.48.0.17   gke-my-cluster-default-pool-ded1b785-wvq8   <none>           <none>
  ```

2. ### Установка EFK стека:
  * elasticsearch:
  ```
  kubectl get pods -n observability -l chart=elasticsearch -o wide
  NAME                     READY   STATUS    RESTARTS   AGE   IP          NODE                                      NOMINATED NODE   READINESS GATES
  elasticsearch-master-0   1/1     Running   0          10m   10.48.1.4   gke-my-cluster-infra-pool-4bdb2cc3-xl8g   <none>           <none>
  elasticsearch-master-1   1/1     Running   0          10m   10.48.8.2   gke-my-cluster-infra-pool-4bdb2cc3-7j1l   <none>           <none>
  elasticsearch-master-2   1/1     Running   0          10m   10.48.9.2   gke-my-cluster-infra-pool-4bdb2cc3-qhsn   <none>           <none>
  ```

3. ### Мониторинг ElasticSearch:
  * После добавления конфигурации алерта:
  ```
  additionalPrometheusRules:
  - name: elasticsearch.rules
    groups:
    - name: elasticsearch
      rules:
      - alert: ElasticsearchTooFewNodesRunning
        expr: elasticsearch_cluster_health_number_of_nodes < 3
        for: 5m
        labels:
          severity: critical
        annotations:
          description: There are only {{$value}} < 3 ElasticSearch nodes running
          summary: ElasticSearch running on less than 3 nodes
  ```
  и отключения одной ноды алерт сработал;
  ![Пример алерта](https://raw.githubusercontent.com/otus-kuber-2020-04/xUndero_platform/kubernetes-logging/kubernetes-logging/alertmanager.png)

4. ### EFK | nginx ingress:
  * Рассмотрели логи nginx-ingress и визуализировали их;

5. ### Loki:
  * Также создан дашборд с Loki;

## ДЗ 8 Мониторинг сервиса в кластере k8s
1. ### Создание образа nginx:
  * Образ собран с параметром *`--with-http_stub_status_module`*;

2. ### Добавление nginx exporter:
  * В одном поде с nginx запущен exporter;

3. ### Запуск prometheus-operator:
  * Для запуска использовался пример с официального сайта:
    *`https://github.com/coreos/prometheus-operator/blob/master/bundle.yaml`*  
    и создан объект prometheus:
  ```
  apiVersion: monitoring.coreos.com/v1
  kind: Prometheus
  metadata:
    name: prometheus
  spec:
    serviceAccountName: prometheus-operator
    serviceMonitorSelector:
      matchLabels:
        team: frontend
    resources:
      requests:
        memory: 400Mi
    enableAdminAPI: false
  ```
  * После запуска пришлось добавить в ClusterRole действия list и watch для объектов service.

## ДЗ 7 Операторы,CustomResourceDefinition
1. ### CustomResourceDefinition:
  * CustomResource:
  ```
  kubectl apply -f ./deploy/cr.yaml 
  error: unable to recognize "./deploy/cr.yaml": no matches for kind "MySQL" in version "otus.homework/v1"
  ```
  после добавления crd:
  ```
  kubectl get ms
  NAME             AGE
  mysql-instance   26s
  ```
  после добавления валидации:
  ```
  kubectl apply -f ./cr.yaml 
  error: error validating "./cr.yaml": error validating data: ValidationError(MySQL): unknown field "usless_data" in homework.otus.v1.MySQL; if you choose to ignore these errors, turn validation off with --validate=false
  ```
  неплохо-бы упомянуть, что с весии 1.16 версия api изменена на apiextensions.k8s.io/v1
  и validation на schema;  
  Для задания обязательных полей используется *`required: ["image","database","password","storage_size"]`*
  ```
  kubectl apply -f ./cr.yaml
  error: error validating "./cr.yaml": error validating data: ValidationError(MySQL.spec): missing required field "password" in homework.otus.v1.MySQL.spec; if you choose to ignore these errors, turn validation off with --validate=false
  ```
  
2. ### Контроллер:
  * Запустили предложенный контроллер:
  ```
  [2020-06-17 19:47:11,197] kopf.objects         [INFO    ] [default/mysql-instance] Handler 'mysql_on_create' succeeded.
  [2020-06-17 19:47:11,198] kopf.objects         [INFO    ] [default/mysql-instance] All handlers succeeded for creation.
  ```
  При запуске контроллера CR уже был создан, но события о нём продолжают периодически приходить,
  поэтому сработала функция и создались ресурсы.
  * После внесения всех изменений получаем и до и после удаления и восстановления объекта mysql:
  ```
  +----+-------------+
  | id | name        |
  +----+-------------+
  |  1 | some data   |
  |  2 | some data-2 |
  +----+-------------+
  ```
  * Для создания образа использовался образ python:3.7-slim.
  После деплоя оператора после создания и пересоздания объекта mysql:
  ```
  export MYSQLPOD=$(kubectl get pods -l app=mysql-instance -o jsonpath="{.items[*].metadata.name}")
  kubectl exec -it $MYSQLPOD -- mysql -potuspassword -e "select * from test;" otus-database
  +----+-------------+
  | id | name        |
  +----+-------------+
  |  1 | some data   |
  |  2 | some data-2 |
  |  3 | some data-3 |
  |  4 | some data-4 |
  +----+-------------+

  kubectl get jobs
  NAME                         COMPLETIONS   DURATION   AGE
  restore-mysql-instance-job   1/1           10s        5m21s
  ```  

## ДЗ 6 Шаблонизация манифестов Kubernetes
1. ### Установка готовых Helm charts:
  * nginx-ingress:
  ```
  kubectl get all -n nginx-ingress
  NAME                                                 READY   STATUS    RESTARTS   AGE
  pod/nginx-ingress-controller-8545f845c4-fjx96        1/1     Running   0          44h
  pod/nginx-ingress-default-backend-59944969d4-8dw4n   1/1     Running   0          43h

  NAME                                    TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
  service/nginx-ingress-controller        LoadBalancer   10.51.247.204   34.77.85.33   80:31152/TCP,443:32052/TCP   8d
  service/nginx-ingress-default-backend   ClusterIP      10.51.244.101   <none>        80/TCP                       8d

  NAME                                            READY   UP-TO-DATE   AVAILABLE   AGE
  deployment.apps/nginx-ingress-controller        1/1     1            1           8d
  deployment.apps/nginx-ingress-default-backend   1/1     1            1           8d

  NAME                                                       DESIRED   CURRENT   READY   AGE
  replicaset.apps/nginx-ingress-controller-8545f845c4        1         1         1       8d
  replicaset.apps/nginx-ingress-default-backend-59944969d4   1         1         1       8d
  ```
  * cert-manager:
    Для установки cert-manager-а использовали следующие команды:
    ```
    kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.15.1/cert-manager.crds.yaml
    helm install \\n  cert-manager jetstack/cert-manager \\n  --namespace cert-manager \\n  --version v0.15.1 \\n  --set ingressShim.defaultIssuerName=example-iss
    uer \\n  --set ingressShim.defaultIssuerKind=ClusterIssuer \\n  --set ingressShim.defaultIssuerGroup=cert-manager.io
    ```
    И для корректной работы должен быть создан ClusterIssuer;
  * chartmuseum:
    Сделаны настройки Ingress:
    ```
    ingress:
      enabled: true
      annotations:
        kubernetes.io/ingress.class: nginx
        kubernetes.io/tls-acme: "true"
        certmanager.k8s.io/cluster-issuer: "example-issuer"
        certmanager.k8s.io/acme-challenge-type: http01
      hosts:
        - name: chartmuseum.34.77.85.33.nip.io
          path: /
          tls: true
          tlsSecret: chartmuseum.34.77.85.33.nip.io
    ```
    Для работы с chartmuseum используются следующие команды:
    ```
    helm package .
    curl --data-binary "@mychart-0.1.0.tgz" https://chartmuseum.34.77.85.33.nip.io/api/charts
    либо:
    helm repo add chartmuseum https://chartmuseum.34.77.85.33.nip.io
    helm plugin install https://github.com/chartmuseum/helm-push.git
    helm push mychart/ chartmuseum
    а для установки:
    helm install chartmuseum/mychart
    ```
  * harbor:
  Установлен harbor:
  ```
  kubectl get secrets -n harbor -l owner=helm
  NAME                           TYPE                 DATA   AGE
  sh.helm.release.v1.harbor.v1   helm.sh/release.v1   1      7d22h
  ```
  Создан helmfile для установки nginx-ingress,cert-manager и harbor;

2. ### Создание собственного Helm chart:
  * Из чарта hipster-shop выделен сервис frontend и созданы параметры для его запуска:
  ```
  image:
    tag: v0.1.3

  replicas: 1

  service:
    type: NodePort
    port: 80
    targetPort: 8080
    NodePort: 30001
  ```
  frontend добавлен в зависимости hipster-shop:
  ```
  dependencies:
    - name: frontend
    version: 0.1.0
    repository: "file://../frontend"
  ```
  И изменены параметры при запуске:
  *` helm upgrade --install hipster-shop ./ --namespace hipster-shop --set frontend.service.NodePort=31234 `*

3. ### Kubecfg:
  С помощью jsonnet созданы манифесты сервисов paymentservice и shippingservice;

4. ### Kustomize:
  Получили структуру каталогов:
  ```
  /kustomize
  ├── base
  │   ├── ad-deployment.yaml
  │   ├── ad-service.yaml
  │   └── kustomization.yaml
  └── overrides
      ├── hipster-shop
      │   └── kustomization.yaml
      └── hipster-shop-prod
          └── kustomization.yaml
  ```

## ДЗ 5 Volumes, Storages,StatefulSet
1. ### Создание StatefulSet:
  ```
  kubectl get all                                
  NAME          READY   STATUS    RESTARTS   AGE
  pod/minio-0   1/1     Running   0          53m

  NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE
  service/minio        ClusterIP   None         <none>        9000/TCP   24h

  NAME                     READY   AGE
  statefulset.apps/minio   1/1     53m

  kubectl describe pv 
  Name:              pvc-64f23db0-549b-402d-b4be-b8f1e6e36b63
  Labels:            <none>
  Annotations:       pv.kubernetes.io/provisioned-by: rancher.io/local-path
  Finalizers:        [kubernetes.io/pv-protection]
  StorageClass:      standard
  Status:            Bound
  Claim:             default/data-minio-0
  Reclaim Policy:    Delete
  Access Modes:      RWO
  VolumeMode:        Filesystem
  Capacity:          10Gi
  Node Affinity:     
    Required Terms:  
      Term 0:        kubernetes.io/hostname in [kind-control-plane]
  Message:           
  Source:
      Type:          HostPath (bare host directory volume)
      Path:          /var/local-path-provisioner/pvc-64f23db0-549b-402d-b4be-b8f1e6e36b63
      HostPathType:  DirectoryOrCreate
  ```
  * Для проверки пробросили порт, затем вошли с помощью браузера и создали bucket;
    Затем проверили в консоли:
    ```
    mc config host add minio http://localhost:9000
    mc ls minio
    [2020-05-27 22:38:07 +05]      0B big-bucket/
    [2020-05-27 22:50:52 +05]      0B new-bucket/
    ```

2. ### Создание Secrets:
  * Для создания манифеста secret данные были перекодированы:
  ```
  echo -n minio | base64
  echo -n minio123 | base64
  ```

## ДЗ 4 Сетевое взаимодействие
1. ### Работа с тестовым веб-приложением:
  * Добавление проверок Pod:
    * Получили проверки:
    ```
    Liveness:     tcp-socket :8000 delay=0s timeout=1s period=10s #success=1 #failure=3
    Readiness:    http-get http://:8000/index.html delay=0s timeout=1s period=10s #success=1 #failure=3
    ```
    * По вопросу: конфигурация livenessProbe не имеет смысла, т. к. код возврата команды всегда 0
      (возможно имеет смысл, когда следует проверить наличие команд ps и/или grep)
  * Создание объекта Deployment:
    * Deployment развёрнут:
    ```
    Conditions:
    Type           Status  Reason
    ----           ------  ------
    Available      True    MinimumReplicasAvailable
    Progressing    True    NewReplicaSetAvailable
    ```
    И проверили варианты стратегии (вариант с двумя 0 неприемлем!)
  * Добавление сервисов в кластер (ClusterIP):
    ```
    kubectl describe service web-svc-cip 
    Name:              web-svc-cip
    Namespace:         default
    Labels:            <none>
    Annotations:       Selector:  app=web
    Type:              ClusterIP
    IP:                10.97.48.101
    Port:              <unset>  80/TCP
    TargetPort:        8000/TCP
    Endpoints:         172.17.0.10:8000,172.17.0.7:8000,172.17.0.9:8000
    ```
  * Включение режима балансировки IPVS.


2. ### Доступ к приложению извне кластера:
  * Установка MetalLB в Layer2-режиме;
  * Добавление сервиса LoadBalancer:
    ```
    kubectl describe service web-svc-lb 
    Name:                     web-svc-lb
    Namespace:                default
    Labels:                   <none>
    Annotations:              Selector:  app=web
    Type:                     LoadBalancer
    IP:                       10.111.178.234
    LoadBalancer Ingress:     172.17.255.1
    Port:                     <unset>  80/TCP
    TargetPort:               8000/TCP
    NodePort:                 <unset>  31258/TCP
    Endpoints:                172.17.0.10:8000,172.17.0.7:8000,172.17.0.9:8000
    Session Affinity:         None
    External Traffic Policy:  Cluster
    ```
    * Сервис получил адрес из пула адресов MetalLB;
    * После создания сервиса для coredns проверим его работу:
    ```
    nslookup web-svc-cip.default.svc.cluster.local 172.17.255.10
    Server:		172.17.255.10
    Address:	172.17.255.10#53

    Name:	web-svc-cip.default.svc.cluster.local
    Address: 10.97.48.101
    ```
  * Установка Ingress-контроллера и прокси ingress-nginx;
  * Создание правил Ingress:
    * Создано правило для отображения дашборда через Ingress;
    * Использован Ingress для переключения части запросов на специально созданный deployment:
      Для основного и тестового релизов использовалось имя хоста testweb.io
      и для проверки применялись команды:
      ```
      curl --resolve testweb.io:80:172.17.255.2 http://testweb.io/web
      curl -H "canary: always" --resolve testweb.io:80:172.17.255.2 http://testweb.io/web
      ```

## ДЗ 3 Security
1. ### task01;
  * В результате получились файлы:
    ```
    01-serviceaccount.yaml
    02-clusterrolebinding.yaml
    03-serviceaccount.yaml
    ```
2. ### task02;
  * В результате получились файлы:
    ```
    01-namespace.yaml
    02-serviceaccount.yaml
    03-clusterrole.yaml
    04-clusterrolebinding.yaml
    ```
    * Для получения шаблона кластерной роли я использовал команду:  
    *`kubectl get clusterrole view -o yaml > 03-clusterrole.yaml`*

3. ### task03;
  * В результате получились файлы:
    ```
    01-namespace.yaml
    02-serviceaccount.yaml
    03-rolebinding.yaml
    04-serviceaccount.yaml
    05-rolebinding.yaml

    kubectl -n dev get serviceaccounts,rolebindings
    NAME                     SECRETS   AGE
    serviceaccount/default   1         52m
    serviceaccount/jane      1         52m
    serviceaccount/ken       1         51m

    NAME                                                   ROLE                AGE
    rolebinding.rbac.authorization.k8s.io/dev-admin-jane   ClusterRole/admin   51m
    rolebinding.rbac.authorization.k8s.io/dev-view-ken     ClusterRole/view    50m
    ```

## ДЗ 2 Kubernetes controllers
1. ### Запуск кластера в kind;
2. ### Проверка работы контроллеров:
  * ReplicaSet;
    * Обновление с ReplicaSet происходит только при пересоздании pod-ов, т. к. ReplicaSet не отслеживает изменения спецификации в шаблоне;
    * После применения обновлённого манифеста
    ```
    kubectl get replicaset frontend -o=jsonpath='{.spec.template.spec.containers[0].image}'
    xunder/frontend:v0.0.2

    kubectl get pods -l app=frontend -o=jsonpath='{.items[0:3].spec.containers[0].image}'
    xunder/frontend:v0.0.1 xunder/frontend:v0.0.1 xunder/frontend:v0.0.1
    ```
    * После удаления pod-ов
    ```
    kubectl get replicaset frontend -o=jsonpath='{.spec.template.spec.containers[0].image}'
    xunder/frontend:v0.0.2

    kubectl get pods -l app=frontend -o=jsonpath='{.items[0:3].spec.containers[0].image}'
    xunder/frontend:v0.0.2 xunder/frontend:v0.0.2 xunder/frontend:v0.0.2
    ```
  * Deployment;
    * Созданы манифесты для реализации двух указанных сценариев развёртывания: blue-green и reverse;
  * Probes;
    * После изменения версии и поломки теста:
    ```
    kubectl get pods     
    NAME                       READY   STATUS    RESTARTS   AGE
    frontend-64f4c767b-bqhln   1/1     Running   0          7m43s
    frontend-64f4c767b-kc9nm   1/1     Running   0          7m43s
    frontend-64f4c767b-mx2rl   1/1     Running   0          7m43s
    frontend-f697d8c85-7fclj   0/1     Running   0          96s

    kubectl describe pods
    Events:
    Type     Reason     Age        From                   Message
    ----     ------     ----       ----                   -------
    Warning  Unhealthy  9s         kubelet, kind-worker3  Readiness probe failed: HTTP probe failed with statuscode: 404
    ```
  * DaemonSet;
    * Создан манифест для запуска node-exporter;
    ```
    kubectl get pods -l component=node-exporter -o wide
    NAME                             READY   STATUS    RESTARTS   AGE   IP           NODE               
    prometheus-node-exporter-22bbd   1/1     Running   0          52m   172.17.0.3   kind-worker3       
    prometheus-node-exporter-2fvm5   1/1     Running   0          52m   172.17.0.6   kind-control-plane 
    prometheus-node-exporter-4bbmc   1/1     Running   0          52m   172.17.0.8   kind-control-plane3
    prometheus-node-exporter-7gbjv   1/1     Running   0          52m   172.17.0.5   kind-worker2       
    prometheus-node-exporter-bj7mb   1/1     Running   0          52m   172.17.0.7   kind-control-plane2
    prometheus-node-exporter-gld6t   1/1     Running   0          52m   172.17.0.4   kind-worker        
    ```
    * Для запрета запуска pod-ов на определённых нодах (в данном случае - master) присутствуют метки (taints)
      и чтобы обойти фильтры этих меток в настройках pod-ов (и их контроллеров) вводятся tolerations.

## ДЗ 1 Знакомство с kubernetes
1. #### Настройка локального окружения:
  * Запуск кластера с помощью minikube с драйвером docker (опробован также запуск с kind);
  * Рассмотрены инструменты Dashboard и k9s;
  * При остановке pod-ов они восстанавливаются, т.к. судя по описанию:
    * core-dns управляется с помощью ReplicaSet,
    * kube-proxy управляется с помощью DaemonSet,
    * etcd, apiserver, controller, scheduler - статические pod-ы, которыми управляет kubelet на master-ноде;
2. #### Создание нового pod-а:
  * Создание Dockerfile для pod-а;
  * Добавление в pod init контейнера;
3. #### Запуск frontend;
  * При запуске из созданного манифеста контейнер пишет, что не опредедена переменная PRODUCT_CATALOG_SERVICE_ADDR;
  * После добавления этой переменной и других переменных, указанных в манифесте по ссылке, pod запустился.
