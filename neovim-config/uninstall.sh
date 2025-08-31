#!/bin/bash

# 确保脚本以非root用户运行
if [ "$(id -u)" -eq 0 ]; then
    echo "请不要以root用户运行此脚本"
    exit 1
fi

# 确认用户要卸载
read -p "确定要卸载Neovim配置吗？(y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "卸载已取消"
    exit 0
fi

# 删除配置文件
echo "删除配置文件..."
rm -rf ~/.config/nvim

# 删除插件目录
echo "删除插件目录..."
rm -rf ~/.local/share/nvim/lazy
rm -rf ~/.local/state/nvim

# 提示用户是否要删除Neovim本身
read -p "是否要删除Neovim程序？(y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if command -v nvim &> /dev/null; then
        echo "尝试删除Neovim程序..."
        
        # 检测操作系统
        if [ -f /etc/debian_version ]; then
            # Debian/Ubuntu
            sudo apt-get remove --purge -y neovim
        elif [ -f /etc/redhat-release ]; then
            # RHEL/CentOS
            sudo yum remove -y neovim
        elif [ "$(uname)" == "Darwin" ]; then
            # macOS
            if command -v brew &> /dev/null; then
                brew uninstall neovim
            else
                echo "请手动删除Neovim"
            fi
        else
            echo "请手动删除Neovim"
        fi
    else
        echo "Neovim未安装"
    fi
fi

echo "Neovim配置卸载完成！"    