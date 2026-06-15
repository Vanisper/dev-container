#!/usr/bin/env bash

TOOLCHAIN_ORDER=(go node python rust)
COMPOSE_TEMPLATE="envs/docker-compose.template.yml"
GENERATED_DIR=".generated"
GENERATED_COMPOSE_FILE="$GENERATED_DIR/docker-compose.yml"
ACTIVE_ENV_FILE=".active-env"
DEV_ENV_HOME="/opt/dev-env"
SYSTEM_PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

list_toolchains() {
    printf '%s\n' "${TOOLCHAIN_ORDER[@]}"
}

print_toolchains() {
    list_toolchains | sed 's/^/  - /'
}

is_valid_toolchain() {
    case "$1" in
        go|node|python|rust) return 0 ;;
        *) return 1 ;;
    esac
}

is_valid_source() {
    case "$1" in
        default|auto|custom) return 0 ;;
        *) return 1 ;;
    esac
}

contains_word() {
    case " $1 " in
        *" $2 "*) return 0 ;;
        *) return 1 ;;
    esac
}

set_tool_source() {
    local tool=$1 source=$2
    case "$tool" in
        go) source_go=$source ;;
        node) source_node=$source ;;
        python) source_python=$source ;;
        rust) source_rust=$source ;;
    esac
}

get_tool_source() {
    case "$1" in
        go) printf '%s\n' "${source_go:-}" ;;
        node) printf '%s\n' "${source_node:-}" ;;
        python) printf '%s\n' "${source_python:-}" ;;
        rust) printf '%s\n' "${source_rust:-}" ;;
    esac
}

normalize_envs() {
    local raw token tool source ordered env env_source
    raw=${1:-}
    raw=${raw//,/ }

    source_go=""
    source_node=""
    source_python=""
    source_rust=""

    if [ -z "${raw// /}" ]; then
        return 1
    fi

    for token in $raw; do
        if [[ "$token" == *"|"* ]]; then
            return 4
        fi
        if [ "$token" = "all" ]; then
            for tool in "${TOOLCHAIN_ORDER[@]}"; do
                set_tool_source "$tool" default
            done
            continue
        fi

        tool=${token%%@*}
        if [[ "$token" == *"@"* ]]; then
            source=${token#*@}
        else
            source=default
        fi

        is_valid_toolchain "$tool" || return 2
        is_valid_source "$source" || return 3
        set_tool_source "$tool" "$source"
    done

    ordered=""
    for env in "${TOOLCHAIN_ORDER[@]}"; do
        env_source="$(get_tool_source "$env")"
        if [ -n "$env_source" ]; then
            if [ "$env_source" = "default" ]; then
                ordered="${ordered:+$ordered,}$env"
            else
                ordered="${ordered:+$ordered,}$env@$env_source"
            fi
        fi
    done

    [ -n "$ordered" ] || return 1
    printf '%s\n' "$ordered"
}

env_tools() {
    local normalized=$1 token tool result
    result=""
    normalized=${normalized//,/ }
    for token in $normalized; do
        tool=${token%%@*}
        result="${result:+$result,}$tool"
    done
    printf '%s\n' "$result"
}

env_slug() {
    local normalized=$1
    printf '%s\n' "$normalized" | tr ',@' '--'
}

runtime_path_for_envs() {
    local normalized=${1:-} token tool entries
    entries=""
    normalized=${normalized//,/ }

    for token in $normalized; do
        tool=${token%%@*}
        case "$tool" in
            go)
                entries="${entries:+$entries:}$DEV_ENV_HOME/go/toolchain/bin:$DEV_ENV_HOME/go/home/bin"
                ;;
            node)
                entries="${entries:+$entries:}$DEV_ENV_HOME/node/toolchain/bin"
                ;;
            python)
                entries="${entries:+$entries:}$DEV_ENV_HOME/python/toolchain/bin:/home/dev/.local/bin"
                ;;
            rust)
                entries="${entries:+$entries:}$DEV_ENV_HOME/rust/home/cargo/bin"
                ;;
        esac
    done

    printf '%s\n' "${entries:+$entries:}$SYSTEM_PATH"
}

read_env_value() {
    local key=$1
    sed -n "s/^${key}=//p" .env 2>/dev/null | tail -n 1
}

compose_project_name() {
    local env_project_name
    env_project_name="$(read_env_value COMPOSE_PROJECT_NAME)"
    printf '%s\n' "${COMPOSE_PROJECT_NAME:-${env_project_name:-dev}}"
}

dev_image_name() {
    local normalized=$1
    printf '%s\n' "$(compose_project_name)-$(env_slug "$normalized"):latest"
}

validate_source_value() {
    local key=$1 value=$2
    case "$value" in
        *";"*|*$'\n'*|*$'\r'*)
            echo "❌ $key 的值不能包含分号或换行" >&2
            exit 1
            ;;
    esac
}

source_profile_for_envs() {
    local normalized=$1 token tool source module_dir vars var auto_var value entries provided
    entries=""
    normalized=${normalized//,/ }

    for token in $normalized; do
        tool=${token%%@*}
        if [[ "$token" == *"@"* ]]; then
            source=${token#*@}
        else
            source=default
        fi
        [ "$source" != "default" ] || continue

        module_dir="envs/$tool"
        [ -f "$module_dir/sources.env" ] || {
            echo "❌ $tool 不支持 source profile：缺少 $module_dir/sources.env" >&2
            exit 1
        }

        SOURCE_VARS=""
        # shellcheck source=/dev/null
        source "$module_dir/sources.env"
        vars=${SOURCE_VARS:-}
        [ -n "$vars" ] || {
            echo "❌ $tool 的 sources.env 未声明 SOURCE_VARS" >&2
            exit 1
        }

        provided=0
        for var in $vars; do
            case "$source" in
                auto)
                    auto_var="AUTO_$var"
                    value=${!auto_var:-}
                    [ -n "$value" ] || {
                        echo "❌ $tool@auto 缺少 $auto_var" >&2
                        exit 1
                    }
                    ;;
                custom)
                    value="$(read_env_value "$var")"
                    [ -n "$value" ] || continue
                    ;;
            esac
            validate_source_value "$var" "$value"
            entries="${entries:+$entries;}$var=$value"
            provided=1
        done
        if [ "$source" = "custom" ] && [ "$provided" = "0" ]; then
            echo "❌ $tool@custom 至少需要在 .env 中配置一个 $tool 的自定义源变量：$vars" >&2
            exit 1
        fi
    done

    printf '%s\n' "$entries"
}

compose_cmd() {
    local normalized=${1:-}
    local image=${2:-}
    local source_profile=${3:-}
    local project_name project_root enabled_tools runtime_path
    project_name="$(compose_project_name)"
    project_root="$(pwd)"
    enabled_tools="${normalized:+$(env_tools "$normalized")}"
    runtime_path="$(runtime_path_for_envs "$normalized")"

    local cmd=(env "COMPOSE_PROJECT_NAME=$project_name" "PROJECT_ROOT=$project_root" "DEV_ENV_HOME=$DEV_ENV_HOME" "DEV_ENV_PATH=$runtime_path")
    if [ -n "$normalized" ]; then
        cmd+=("ENABLED_ENVS=$normalized" "ENABLED_TOOLS=$enabled_tools")
    fi
    if [ -n "$image" ]; then
        cmd+=("DEV_IMAGE=$image")
    fi
    if [ -n "$source_profile" ]; then
        cmd+=("SOURCE_PROFILE=$source_profile")
    fi
    cmd+=(docker compose --env-file .env -f "$GENERATED_COMPOSE_FILE")
    printf '%q ' "${cmd[@]}"
}

validate_compose_fragment() {
    local fragment=$1
    awk '
        /^[[:space:]]*$/ || /^[[:space:]]*#/ { next }
        /^services:[[:space:]]*$/ { seen_services=1; next }
        /^  dev:[[:space:]]*$/ && seen_services { seen_dev=1; next }
        /^    (volumes|environment):[[:space:]]*$/ && seen_dev { section=$1; sub(":", "", section); next }
        /^      - / && section == "volumes" { next }
        /^      [A-Za-z_][A-Za-z0-9_]*:[[:space:]]*/ && section == "environment" {
            key=$1
            sub(":", "", key)
            if (key ~ /^(APT_MIRROR|COMPOSE_PROJECT_NAME|DEV_ENV_HOME|DEV_ENV_PATH|DEV_GID|DEV_IMAGE|DEV_UID|ENABLED_ENVS|ENABLED_TOOLS|GID|PATH|PROJECT_ROOT|SHARED_HOST|SOURCE_PROFILE|UID|WORKSPACE_HOST)$/) {
                printf("❌ %s 不能覆盖受保护的环境变量：%s\n", FILENAME, key) > "/dev/stderr"
                exit 1
            }
            next
        }
        {
            printf("❌ %s 包含不允许的 compose 字段或格式：%s\n", FILENAME, $0) > "/dev/stderr"
            exit 1
        }
    ' "$fragment"
}

extract_fragment_section() {
    local fragment=$1 section_name=$2
    awk -v want="$section_name" '
        /^    volumes:[[:space:]]*$/ { section="volumes"; next }
        /^    environment:[[:space:]]*$/ { section="environment"; next }
        /^    [A-Za-z_][A-Za-z0-9_-]*:/ { section=""; next }
        section == want && /^      / { print }
    ' "$fragment"
}

generate_compose() {
    local normalized=$1 image=$2 token tool fragment volumes_file environment_file line
    mkdir -p "$GENERATED_DIR"
    volumes_file="$GENERATED_DIR/module-volumes.yml"
    environment_file="$GENERATED_DIR/module-environment.yml"
    : > "$volumes_file"
    : > "$environment_file"

    normalized=${normalized//,/ }
    for token in $normalized; do
        tool=${token%%@*}
        fragment="envs/$tool/compose.fragment.yml"
        [ -f "$fragment" ] || continue
        validate_compose_fragment "$fragment"
        extract_fragment_section "$fragment" volumes >> "$volumes_file"
        extract_fragment_section "$fragment" environment >> "$environment_file"
    done

    {
        while IFS= read -r line; do
            case "$line" in
                *"# MODULE_VOLUMES"*)
                    cat "$volumes_file"
                    ;;
                *"# MODULE_ENVIRONMENT"*)
                    cat "$environment_file"
                    ;;
                *)
                    printf '%s\n' "$line"
                    ;;
            esac
        done < "$COMPOSE_TEMPLATE"
    } > "$GENERATED_COMPOSE_FILE"
}

prepare_compose() {
    local normalized=$1 image=$2
    generate_compose "$normalized" "$image"
}

prepare_runtime_dirs() {
    mkdir -p \
        "$GENERATED_DIR" \
        workspace \
        shared/.ssh \
        volumes \
        volumes/go-home \
        volumes/go-cache \
        volumes/node-cache \
        volumes/python-cache \
        volumes/rust-cargo \
        volumes/rust-target

    local dev_uid dev_gid
    dev_uid="$(read_env_value DEV_UID)"
    dev_gid="$(read_env_value DEV_GID)"
    if [ "$(id -u)" = "0" ] || [ "$(id -g)" = "0" ]; then
        chown -R "${dev_uid:-1000}:${dev_gid:-1000}" workspace volumes
    fi
}

remove_legacy_containers() {
    local project_name legacy
    project_name="$(compose_project_name)"
    for legacy in go node python rust; do
        docker rm -f "${project_name}-${legacy}" >/dev/null 2>&1 || true
    done
}

require_explicit_env() {
    local env_name=${1:-}
    if [ -z "$env_name" ]; then
        echo "❌ 请显式指定 ENV，例如：make up ENV=go@auto,python" >&2
        echo "可用工具链:" >&2
        print_toolchains >&2
        exit 1
    fi
}

normalize_or_exit() {
    local env_name=$1 normalized status
    set +e
    normalized="$(normalize_envs "$env_name")"
    status=$?
    set -e
    case "$status" in
        0)
            printf '%s\n' "$normalized"
            ;;
        1)
            echo "❌ 请至少指定一个工具链，例如：ENV=go@auto,python" >&2
            exit 1
            ;;
        2)
            echo "❌ ENV 包含未知工具链：$env_name" >&2
            echo "可用工具链:" >&2
            print_toolchains >&2
            echo "  - all" >&2
            exit 1
            ;;
        3)
            echo "❌ ENV 包含未知 source：$env_name。可用 source：default,auto,custom" >&2
            exit 1
            ;;
        4)
            echo "❌ ENV source 请使用 @，例如：ENV=go@auto,python。不要使用 |。" >&2
            exit 1
            ;;
        *)
            echo "❌ ENV 解析失败：$env_name" >&2
            exit 1
            ;;
    esac
}

load_active_env() {
    if [ ! -f "$ACTIVE_ENV_FILE" ]; then
        echo "❌ 当前没有激活的 dev 环境，请先执行：make up ENV=go@auto,python" >&2
        exit 1
    fi
    local active
    active="$(tr -d '[:space:]' < "$ACTIVE_ENV_FILE")"
    if [ -z "$active" ]; then
        echo "❌ .active-env 为空，请重新执行：make up ENV=go@auto,python" >&2
        exit 1
    fi
    normalize_or_exit "$active"
}
