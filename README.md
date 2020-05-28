# xUndero_platform
xUndero Platform repository

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

1. ### Создание Secrets:
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
