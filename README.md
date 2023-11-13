# search.sh

Простой скрипт на bash, для поиска переменных окружения в kubernetes/openshift

## Зависимости

- bash (https://www.gnu.org/software/bash/manual/html_node/)
- jq (https://github.com/jqlang/jq)

## Описание доступных действий

```bash
Commands:
  ./search.sh [SEARCH ENV] # Выполнить поиск по названию переменной в деплойментах
  ./search.sh help         # Отображение справки
  ./search.sh update       # Обновление скрипта
  ./search.sh version      # Отображение версии

System environments:
  CONTEXT    # Какой kube-context использовать (по умолчанию current-context)
  NAMESPACE  # Какой kube-namespace использовать (по умолчанию current-context.namespace)
  APPROVE    # Автоматический approve без ожидания ввода

Examples:
  ./search.sh help

  ./search.sh update

  ./search.sh version

  ./search.sh "KEYCLOAK_"

  CONTEXT=context-name ./search.sh "KEYCLOAK_"

  CONTEXT=context-name NAMESPACE=namespace-name ./search.sh "KEYCLOAK_"

  APPROVE=true ./search.sh "KEYCLOAK_"
```
