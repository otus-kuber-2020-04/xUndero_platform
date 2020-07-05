# xUndero_platform
xUndero Platform repository

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
