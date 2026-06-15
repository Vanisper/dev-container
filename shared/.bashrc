# dev-container 基础配置
export PS1='\u@\h:\w\$ '
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'

if [ -f /etc/profile.d/dev-tools.sh ]; then
    # 让交互 shell 使用构建时启用的工具链环境。
    source /etc/profile.d/dev-tools.sh
fi

if command -v python3 >/dev/null 2>&1 && ! command -v python >/dev/null 2>&1; then
    alias python='python3'
fi
if command -v pip3 >/dev/null 2>&1 && ! command -v pip >/dev/null 2>&1; then
    alias pip='pip3'
fi
