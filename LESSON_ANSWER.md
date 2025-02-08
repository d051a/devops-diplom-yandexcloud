# Дипломный практикум в Yandex.Cloud

## Этапы выполнения 
### Создание облачной инфраструктуры

1. Код реализующий поставленную задачу находится в директории ./terraform/bucket 

для запуска необходим файл terraform.auto.tfvars следующего содержимого:
```
token = ""
cloud_id  = ""
folder_id = ""
default_zone = "ru-central1-a"
bucket_name = "test-bucket-diplom"
```

Выполняется стандартным набором команд:

```
terraform init
terraform apply
terraform destroy
```

По результатам создаются: 
- Сервисный аккаунт для доступа
- S3 bucket для хранения стейта
- Registry для хранения собранных образов (в последствии отказался в пользу DockerHub)

Результат выполнения:
![результат выполнения команд terraform](./imgs/1.png)
![инфраструктура в gui yandex cloud #1](./imgs/2.png)
![инфраструктура в gui yandex cloud #2](./imgs/3.png)

---
### Создание Kubernetes кластера
Код реализующий поставленную задачу находится в директории ./terraform/vms Код реализующий настройку сети и запуск виртуальных машин реализон через terraform. 
По результатам выполнения создается файл inventory.ini, который используется в дальнейшем для настройки кластера K8S. 
Запуск инициируется стандартным набором команд:

```
terraform init
terraform apply
terraform destroy
```

Установка K8S реализована через Kubespray.  Все этапы запуска (скачивание Kubespray репозитория, установка необходимой версии ansible, python, зависимостей, копирование inventory.ini и прочих конфигурационных файлов) автоматизированы через запуск скрипта ./terraform/vms/deploy_k8s.sh

Запуск:

```
chmod +x deploy_k8s.sh
sh deploy_k8s.sh
```

По результатам выполнения запускается ansible скрипт Kubespray который настраивает указанные в inventory.ini хосты.
Для удаленного подключения необходимо скопировать с ноды кластера k8s конфиг для подключения:

```
scp ubuntu@IP_MASTER_K8S:/etc/kubernetes/admin.conf ./kube.conf
```

в последующем к кластеру подключаюсь через этот файл командами вида:

```
kubectl --kubeconfig=./kube.conf get pods --all-namespaces
```

Результат выполнения:
![успешная настройка кластера k8s через kubespray](./imgs/4.png)
![проверка состояния кластера через kubectl](./imgs/5.png)

---
### Создание тестового приложения

Было принято решение разместить приложение в открытом репозитории DockerHub (https://hub.docker.com/r/d051a/my-app-nginx)


Само тестовое приложение расположено в директории ./test-app Предварительная сборка, публикация приложения и скачивание образа из Registry DockerHub осуществляется через следующие команды:

```
docker build --platform linux/amd64 -t d051a/my-app-nginx:1.0.0 .
docker push d051a/my-app-nginx:3.0.0

docker pull d051a/my-app-nginx:3.0.0
```

Результат выполнения:
![выполнение команы docker push](./imgs/6.png)
![отображение опубликованного приложения в gui yandex cloud](./imgs/7.png)



---
### Подготовка cистемы мониторинга и деплой приложения
Для реализации задачи было выбрано решение установки мониторинга через helm-charts

Для начала установил `helm` на `control-plane` ноду
```
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
```
Создал отдельное простанство имен для мониторинга
```
kubectl create namespace monitoring
```
Добавил репозиторий `helm` c `prometheus`
```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
```
Устанавил `kube-prometheus-stack` (установка `Prometheus`, `Grafana`, `Alertmanager`, `node-exporter` и `kube-state-metrics`)
```
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring
```
```
kubectl get pods -n monitoring
```

Далее, получил пароль от `Grafana`
```
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```
Настроил доступ к `Grafana` по внешнему ip адресу, для чего создал файл values.yml
```yml
grafana:
  service:
    type: NodePort
    nodePort: 32000 
```
```
helm upgrade prometheus prometheus-community/kube-prometheus-stack -n monitoring -f values.yml
```

Далее настраиваем необходимые метрики из стандартного шаблона `Grafana` - [ID 315](https://grafana.com/grafana/dashboards/315-kubernetes-cluster-monitoring-via-prometheus/)


Результат выполнения:
![](./imgs/15.png)
![](./imgs/16.png)
![](./imgs/17.png)
![](./imgs/18.png)


Само приложение было размещено в репозитории Gitlab (https://gitlab.com/d051a/netology_devops_course) Там же расположен код для деплоя приложения - файл deploy-k8s.yml. Код самого приложения и код для деплоя приложения продублирован в директории ./test-app в этом проекте. Также был зарегистрирован бесплатный домен netology.zapto.org

Для деплоя приложения в среду k8s выполняем команду:

```
kubectl apply --kubeconfig=./kube.conf -f deploy-k8s.yml
```

Результат выполнения:
![](./imgs/8.png)
![](./imgs/9.png)
![](./imgs/10.png)

---
### Установка и настройка CI/CD

CD/CD реализовано на базе Gitlab-CI
Для реализации пайплайна в settings - cicd добавлены переменные для подключения к dockerHub и файл для подключения к кластеру k8s.

Пайплайн состоит из двух стадий: build и deploy

На этапе build идет сборка проекта и собранный образ сохраняется в dockerHub.

На этапе deploy выполняется разворачивание приложения из ранее созданного образа.

файл .gitlab-ci.yml расположен в директории ./test-app/ в этом проекте .gitlab-ci.yml , а также в репозитории проекта на GitLab (https://gitlab.com/d051a/netology_devops_course)


Результат выполнения:
![pipline](./imgs/11.png)
![build](./imgs/12.png)
![deploy](./imgs/13.png)

---

## Этапы выполнения по результатам доработки

1. Изменяете ли вы код кубеспрея кроме отдельного inventory, который генерируется терраформом? Если да, то где вы его храните?

```
Доработано. В моей реализации после создания инфраструктуры через терраформ создается файл inventory.ini (я его добавил в gitignore случайно, теперь он присутствует в коде). Затем я выполняю скрипт deploy_k8s.sh который копирует директорию inventory/simple в директорию inventory/myproject. Копирует туда мой файл inventory. Добавляет в файл group_vars/k8s_cluster/k8s-cluster.yml supplementary_addresses_in_ssl_keys.
пример в директории ./kubespray_
```


2. Как вы ставили ingress и какой использовали балансировщик? curl -I http://netology.zapto.org у меня выдает ошибку

```
Исправлено: Cчет на yandex.cloud ушел в минус. Пополнил счет. Сейчас доступ есть.

  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
  helm repo update
  helm --kubeconfig=./kube.conf install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.externalIPs="{89.169.152.192,158.160.90.189,158.160.86.141}"
```

3. Старайтесь не копипастить ресурсы терраформа. Вместо этого используйте циклы

```Исправлено. в файле ./vms/main.tf теперь реализация через циклы```

4. Закомментированный код, который не несет смысловой нагрузки лучше убирать. Через полгода вы не вспомните что это и для чего, а того, кто будет ревьюить ваш код это только запутает

```В скрипте deploy_k8s.sh код полностью рабочий. Существенный блок кода был закомментирован мной в рамках тестирования инфраструктуры (забыл снять комментарии перед пушем). Сейчас код раскомментирован.```

5. Если перешли на Dockerhub то удаляйте неиспользуемые ресурсы

```не понял этого пункта ```

6. По условиям дипломной работы требуется доступ к приложению и дашборду графаны по 80 порту (в идеале по 443)\

```К сожалению я не смог добиться работы приложения на 80 порту. Доступ к приложению осуществляется по порту 30080. Я пробовал абсолютно разные настройки для сервиса + ingress. Но приложения так и не смогло запуститься на стандартном порту при переходе на http://netology.zapto.org или например http://89.169.152.192 . Я попробовал посмотреть форки других студентов, но если судить по описанию и скриншотам - большинство работ либо не оформлены должным образом, либо также были сделаны не на стандартном порту. К сожалению у меня не хватает глубоких знаний для тонкой работы кластера. Все выводы нужных команд для диагностики представлены в файле ./commands.txt```

7. По условиям дипломной работы требуется чтобы сборка была при любом коммите (пуше), а деплой при теге. Как сделать так, чтобы деплой запускался только при теге типа semver?

```Исправлено. Код в файле .gitlab-ci.yml доработан. Добавлен теперь при stage deploy выполняется только при добавлении git tag -a v1.0.0 -m "Release version 1.0.0"; git push origin v1.0.0 ```

![deploy](./imgs/19.png)
