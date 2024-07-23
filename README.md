# Проектная работа "Создание процесса непрерывной поставки для приложений с применением практик CI/CD и быстрой обратной связью"

## OTUS DevOps-2024-01

1. Постановка задачи
    - Требуется подготовить инфраструктуру и организовать непрерывную поставку приложений с применением практик CI/CD
    - Приложения: бэк на java, spring framework, фронт js + nginx
    - СУБД PostgresSQL 14
    - Домен bz-otus-project.fun с TLS
    - Должен быть мониторинг, логирование

2. Выбор облачного решения для инфраструктуры
    - Инфраструктура разворачивается в Yandex Cloud
    - Compute cloud instance для ci/cd
    - Managed Service for Kubernetes для развертывания приложений, мониторинга, логирования
    - Managed Service for PostgresSQL как СУБД приложений
    - S3 Object Storage для хранения служебных конфигурационных файлов, в дальнейшем для хранения бизнес документов
      приложений
    - Container Registry для хранения артефактов приложений
    - Lockbox для хранения секретов
    - Certificate manager для управления TLS сертификатами

3. Выбор инструментов
    - ci/cd - Teamcity (в рамках учебного проекта разворачиваем при помощи Docker)
    - terraform - конфигурация и развертывание инфраструктуры
    - helm - деплой приложений
    - helm chart kube-prometheus-stack - мониторинг
    - Приложения для k8s: Ingress nginx, externalDNS, cert-manager-webhook-yandex
    - TODO логирование

4. Создаем ВМ в compute cloud и разворачиваем Teamcity

   В рамках учебного проекта будем использовать docker версию Teamcity, конфигурация Teamcity сервера и агентов, а так
   же Docker-compose файл расположен в директории teamcity
   На созданной ВМ производим развертывание при помощи docker-machine (скрипт teamcity/deploy.sh), по публичному адресу
   ВМ из браузера производим первоначальную конфигурацию Teamcity

5. Конфигурация инфраструктуры при помощи terraform

    1. Модуль modules/bd - конфигурация Managed Service for PostgresSQL
        - Создаем подсеть для кластера postgresql в соответствии с переданными параметрами
        - Создаем кластер postgresql в соответствии с переданными параметрами
        - Создаем БД в соответствии с переданными параметрами
        - Создаем пользователей БД в соответствии с переданными параметрами (пароли хранятся в lockbox)

    2. Модуль modules/k8s - конфигурация Managed Service for Kubernetes
        - Создаем подсеть для k8s в соответствии с переданными параметрами
        - Создаем группы безопасности для
          k8s https://yandex.cloud/ru/docs/managed-kubernetes/operations/connect/security-groups
        - Создаем сервисные аккаунты для k8s и ci/cd и добавляем необходимые роли
        - Создаем master и worker ноды в соответствии с переданными параметрами

    3. Создаем домен и TLS сертификат к нему
        - Создаем домен bz-otus-project.fun указываем DNS-сервера Яндекса ns1.yandexcloud.net, ns2.yandexcloud.net
        - Выпускаем сертификат Let's Encrypt и проходим
          валидацию https://yandex.cloud/ru/docs/certificate-manager/quickstart/?from=int-console-help-center-or-nav

    4. Устанавливаем Ingress-контроллер NGINX с менеджером для сертификатов Let's Encrypt
       https://yandex.cloud/ru/docs/managed-kubernetes/tutorials/ingress-cert-manager#marketplace_1
        - Устанавливаем приложение externalDNS из маркетплейса (TODO автоматизировать)
        - Устанавливаем Ingress при помощи helm провайдера
        - Устанавливаем приложение cert-manager из маркетплейса (TODO автоматизировать)

    5. Устанавливаем kube-prometheus-stack при помощи helm провайдера
        - В files/monitoring-prod.yaml конфигурируем приложение (в основном настраиваем ingress'ы)
        - Поскольку prometheus не имеет своей аутентификации, а мы хотим иметь доступ снаружи - в ingress добавляем
          basic auth

6. Делаем скрипты plan и apply для использования в Teamcity
    - prod/prepare.sh - yc cli config + terraform init + вытаскиваем пароли из lockbox
    - prod/plan.sh - terraform plan
    - prod/apply.sh - terraform apply

7. Создаем пайплайны в Teamcity для деплоя инфраструктуры
    - terraform plan prod - plan для прода, создает tfplan файл, в логах можно посмотреть конфигурацию
    - terraform apply prod - применение плана деплоя

8. В каждом бизнес-приложении создаем helm chart состоящий из следующих ресурсов
    - deployment
    - service
    - ingress
    - prometheusRule
    - serviceMonitor
    - secret
   
9. Настраиваем пайплайны в Teamcity по сборке и деплою приложений
    - артефакты - docker образы приложений сохраняются в Yandex Container Registry
    - деплой при помощи helm
