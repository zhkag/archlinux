#!/bin/bash

# 确保脚本以非root用户运行
if [ "$(id -u)" -eq 0 ]; then
    echo "请不要以root用户运行此脚本"
    exit 1
fi

# 检测操作系统
OS=$(uname -s)
echo "检测到操作系统: $OS"

# 检查依赖
echo "检查必要的依赖..."
for cmd in git curl; do
    if ! command -v $cmd &> /dev/null; then
        echo "错误: 需要安装 $cmd"
        exit 1
    fi
done

# 检查Neovim版本（需要0.8或更高）
if command -v nvim &> /dev/null; then
    NVIM_VERSION=$(nvim --version | head -n 1 | grep -oE '[0-9]+\.[0-9]+')
    if (( $(echo "$NVIM_VERSION < 0.8" | bc -l) )); then
        echo "Neovim版本需要0.8或更高，当前版本：$NVIM_VERSION"
        read -p "是否尝试安装最新版本的Neovim？(y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if [ "$OS" == "Linux" ]; then
                if [ -f /etc/debian_version ]; then
                    # Debian/Ubuntu
                    sudo apt-get update
                    sudo apt-get install -y software-properties-common
                    sudo add-apt-repository ppa:neovim-ppa/unstable -y
                    sudo apt-get update
                    sudo apt-get install -y neovim
                elif [ -f /etc/redhat-release ]; then
                    # RHEL/CentOS
                    sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(rpm -q --qf "%{VERSION}" centos-release).noarch.rpm
                    sudo yum install -y neovim
                else
                    echo "无法自动安装Neovim，请手动安装"
                    exit 1
                fi
            elif [ "$OS" == "Darwin" ]; then
                # macOS
                if command -v brew &> /dev/null; then
                    brew install neovim
                else
                    echo "请先安装Homebrew或手动安装Neovim"
                    exit 1
                fi
            else
                echo "请手动安装Neovim 0.8或更高版本"
                exit 1
            fi
        else
            echo "安装已取消"
            exit 1
        fi
    fi
else
    echo "Neovim未安装"
    read -p "是否尝试安装Neovim？(y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ "$OS" == "Linux" ]; then
            if [ -f /etc/debian_version ]; then
                # Debian/Ubuntu
                sudo apt-get update
                sudo apt-get install -y software-properties-common
                sudo add-apt-repository ppa:neovim-ppa/unstable -y
                sudo apt-get update
                sudo apt-get install -y neovim
            elif [ -f /etc/redhat-release ]; then
                # RHEL/CentOS
                sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(rpm -q --qf "%{VERSION}" centos-release).noarch.rpm
                sudo yum install -y neovim
            else
                echo "无法自动安装Neovim，请手动安装"
                exit 1
            fi
        elif [ "$OS" == "Darwin" ]; then
            # macOS
            if command -v brew &> /dev/null; then
                brew install neovim
            else
                echo "请先安装Homebrew或手动安装Neovim"
                exit 1
            fi
        else
            echo "请手动安装Neovim 0.8或更高版本"
            exit 1
        fi
    else
        echo "安装已取消"
        exit 1
    fi
fi

# 创建配置目录
echo "创建Neovim配置目录..."
mkdir -p ~/.config/nvim

# 复制配置文件
echo "复制配置文件..."
cp -r config/* ~/.config/nvim/

# 创建备份目录
echo "创建备份目录..."
mkdir -p ~/.local/state/nvim/undo
mkdir -p ~/.local/state/nvim/swap
mkdir -p ~/.local/state/nvim/backup

# 安装插件
echo "安装插件..."
nvim --headless "+Lazy! sync" +qa
nvim --headless "+MasonUpdate" "+MasonInstall clangd lua-language-server clang-format cortex-debug lua-language-server python-lsp-server" +qa


echo "Neovim配置安装完成！"
echo "启动Neovim: nvim"