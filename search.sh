#!/usr/bin/env bash

version="0.2.1"

context="${CONTEXT:-$(kubectl config view --minify -o jsonpath='{.contexts...name}')}"
namespace="${NAMESPACE:-$(kubectl config view --minify -o jsonpath='{.contexts..namespace}')}"

approve="${APPROVE:-false}"
json="false"

search="${1}"

function check_requirement {
    kubectl_available=$(command -v kubectl >/dev/null 2>&1 && echo "доступен" || echo "не доступен")
    curl_available=$(command -v curl >/dev/null 2>&1 && echo "доступен" || echo "не доступен")
    jq_available=$(command -v jq >/dev/null 2>&1 && echo "доступен" || echo "не доступен")

    if [[ "$kubectl_available" == "доступен" ]] && \
       [[ "$curl_available" == "доступен" ]] && \
       [[ "$jq_available" == "доступен" ]]
    then
        return 0
    fi

    echo "# ===================================================== #"
    echo "# Некоторые обязательные зависимости недоступны!        #"
    echo "# ===================================================== #"
    echo ""
    echo "- kubectl: $kubectl_available"
    echo "- curl: $curl_available"
    echo "- jq: $jq_available"
    echo ""

    exit 1
}

# check_update
# $1 - 'silent' or '' скрыть подсказку
function check_update {
    mainline_version=$(curl -s --insecure "https://raw.githubusercontent.com/Nayls/search/master/version")

    if [[ ! "$version" == "$mainline_version" ]]; then
        if [[ ! "$1" == 'silent' ]]; then
            echo "# ----------------------------------------------------- #"
            echo "# Доступно обновление: $version -> $mainline_version                   #"
            echo "# ----------------------------------------------------- #"
            echo "# Для обновления выполните ./search.sh update           #"
            echo "# Или скачайте сами https://github.com/Nayls/search     #"
            echo "# ----------------------------------------------------- #"
            echo ""
        fi
        return 1
    fi
    return 0
}

function update {
    source=${BASH_SOURCE[0]}
    while [ -L "$source" ]; do # resolve $source until the file is no longer a symlink
        DIR=$( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )
        source=$(readlink "$source")
        [[ $source != /* ]] && source=$dir/$source # if $source was a relative symlink, we need to resolve it relative to the path where the symlink file was located
    done
    dir=$( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )
    path_to_script="$dir/$(printf $source | sed 's/.\///g')"

    check_update "silent"
    result_check_update=$?

    if [[ "$result_check_update" -eq 1 ]]; then
        echo "- $path_to_script"
        echo ""

        if [ "$approve" == "true" ]; then
            answer='y'
            printf "Вы уверены? (y/n) y"
        else
            read -t15 -n1 -r -p 'Вы уверены? (y/n) ' answer
        fi

        if [ "$answer" == 'y' ]; then
            echo -e " (Подтверждение получено)\n"
            curl -s --insecure "https://raw.githubusercontent.com/Nayls/search/master/search.sh" -o "$path_to_script"
            chmod +x "$path_to_script"
        else
            echo -e " (Подтверждение не получено)\n"
        fi
    else
        echo "# ----------------------------------------------------- #"
        echo "# Актуальная версия, обновление не требуется: $version     #"
        echo "# ----------------------------------------------------- #"
        echo ""
    fi
}

function help {
    echo "Commands:"
    echo "  ./search.sh [SEARCH ENV] [OPTIONS] # Выполнить поиск по названию переменной в деплойментах"
    echo "  ./search.sh help                   # Отображение справки"
    echo "  ./search.sh update                 # Обновление скрипта"
    echo "  ./search.sh version                # Отображение версии"
    echo ""
    echo "Options:"
    echo "  [--json]  # Отобразить найденные данные в json"
    echo ""
    echo "System environments:"
    echo "  CONTEXT    # Какой kube-context использовать (по умолчанию current-context)"
    echo "  NAMESPACE  # Какой kube-namespace использовать (по умолчанию current-context.namespace)"
    echo "  APPROVE    # Автоматический approve без ожидания ввода"
    echo ""
    echo "Examples:"
    echo -e "  ./search.sh help\n"
    echo -e "  ./search.sh update\n"
    echo -e "  ./search.sh version\n"
    echo -e "  ./search.sh \"KEYCLOAK_\"\n"
    echo -e "  ./search.sh \"KEYCLOAK_\" --json\n"
    echo -e "  CONTEXT=context-name ./search.sh \"KEYCLOAK_\"\n"
    echo -e "  CONTEXT=context-name NAMESPACE=namespace-name ./search.sh \"KEYCLOAK_\"\n"
    echo -e "  APPROVE=true ./search.sh \"KEYCLOAK_\"\n"
}

function version {
    echo "$version"
}

# Шаблон поиска по env
#
IFS='' read -r -d '' template_search_env_json <<"EOF" || true
jq -r --arg SEARCH "$search" \
'.items[] | select(.spec.template.spec.containers[].env[]? | select(.name | contains($SEARCH)) and .spec.replicas != 0) | {name: .metadata.name, replicas: .spec.replicas, variable: .spec.template.spec.containers[].env[]? | select(.name | contains($SEARCH))}'
EOF

# Форматирование вывода поиска по env в консоль
#
IFS='' read -r -d '' template_format_search_env <<"EOF" || true
jq -r '.name + ": \"" + .variable.name + ": " + (.variable | if has("valueFrom") then .valueFrom | tostring else .value end) + "\"\"" | sub("^\""; "") | sub("\"$"; "")'
EOF

## search function
#
# $1 - search_word
# $2 - json options
function search {
    echo "# ===================================================== #"
    echo "# Проверьте, что выбран правильный context и namespace! #"
    echo "# ===================================================== #"
    echo ""

    echo "kube context:   $context"
    echo "kube namespace: $namespace"
    echo ""

    echo "search word:    $search"

    echo ""
    echo "---------------------------------------------------------"

    if [ "$approve" == "true" ]; then
        answer='y'
        printf "Вы уверены? (y/n) y"
    else
        read -t15 -n1 -r -p 'Вы уверены? (y/n) ' answer
    fi
    if [ "$answer" == 'y' ]; then
        echo -e " (Подтверждение получено)\n"

        template='eval $template_search_env_json'

        if [[ "$json" == "false" ]]; then
            template+=' | eval $template_format_search_env'
        fi

        kubectl get deployments \
            --namespace="$namespace" \
            --context="$context" \
            -o json | eval "$template"
    else
        echo -e " (Подтверждение не получено)\n"
    fi
}

check_requirement

check_update

if [[ "$1" == 'help' ]] || [[ "$@" == *'-h'* ]]; then
    help
elif [[ "$1" == 'update' ]]; then
    update
elif [[ "$1" == 'version' ]] || [[ "$@" == *'-v'* ]]; then
    version
else
    if [[ "$@" == *'--json'* ]]; then json="true"; fi

    search "$1"
fi
