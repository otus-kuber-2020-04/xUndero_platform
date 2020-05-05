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
