# xUndero_platform
xUndero Platform repository

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
