#!/bin/bash

# 半自动化Arch Linux安装脚本
# 功能：自动分区、格式化、安装系统并配置基本环境
# 支持：手动选择磁盘、文件系统类型

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # 恢复默认颜色

# 日志函数
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# 检查是否有root权限
if [ "$(id -u)" -ne 0 ]; then
    error "请使用root权限运行此脚本！"
fi

# 检查网络连接
log "检查网络连接..."
ping -c 3 archlinux.org >/dev/null 2>&1 || error "网络连接失败，请先连接网络！"

# 1. 检测启动方式
log "检测启动方式..."
if [ -d "/sys/firmware/efi/efivars" ]; then
    BOOT_MODE="UEFI"
    log "系统以UEFI模式启动"
else
    BOOT_MODE="BIOS"
    log "系统以BIOS模式启动"
fi

CPU_VENDOR=$(lscpu | grep "Vendor ID" | awk '{print $3}')

# 2. 选择目标磁盘
log "扫描可用磁盘..."
disks=$(lsblk -d -o NAME,TYPE,SIZE | grep "disk" | grep -v "rom" | awk '{print $1}')

if [ -z "$disks" ]; then
    error "未检测到磁盘设备！"
fi

echo "发现以下磁盘："
echo "----------------"
echo "编号 | 磁盘  | 容量"
echo "----------------"
disk_list=()
counter=1
for disk in $disks; do
    size=$(lsblk -d -o SIZE /dev/$disk | tail -n 1)
    echo "$counter  | $disk  | $size"
    disk_list+=("/dev/$disk")
    counter=$((counter+1))
done
echo "----------------"

if [ "$counter" -eq 2 ]; then
    TARGET_DISK="${disk_list[0]}"
else
    read -p "请选择要安装的磁盘编号 (1-$((counter-1))): " disk_choice
    if ! [[ "$disk_choice" =~ ^[0-9]+$ ]] || [ "$disk_choice" -lt 1 ] || [ "$disk_choice" -ge $counter ]; then
        error "无效的磁盘选择！"
    fi
    TARGET_DISK="${disk_list[$((disk_choice-1))]}"
fi

log "已选择磁盘: ${TARGET_DISK}"

# 3. 选择文件系统
echo ""
echo "请选择根分区文件系统类型："
echo "1. ext4 (稳定性高，兼容性好)"
echo "2. Btrfs (推荐，支持快照、压缩和修复)"
read -p "请选择 (1-2, 默认2): " fs_choice
fs_choice=${fs_choice:-2}

if [ "$fs_choice" -ne 1 ] && [ "$fs_choice" -ne 2 ]; then
    error "无效的文件系统选择！"
fi

if [ "$fs_choice" -eq 1 ]; then
    FILESYSTEM="ext4"
else
    FILESYSTEM="btrfs"
fi
log "已选择文件系统: ${FILESYSTEM}"

echo ""
echo -e "${RED}警告：您即将对磁盘 ${TARGET_DISK} 进行操作！${NC}"
echo "此操作将擦除磁盘上的所有数据！"
echo "安装选项："
echo "  - 启动模式: ${BOOT_MODE}"
echo "  - 文件系统: ${FILESYSTEM}"

read -p "请输入root密码:" ROOTPASSWD
read -p "请输入用户名:" USERNAME
read -p "请输入用户密码:" USERPASSWD
read -p "请输入主机名:" HOSTNAME

# 5. 磁盘准备
log "准备磁盘 ${TARGET_DISK}..."

# 卸载可能已挂载的分区
umount ${TARGET_DISK}* >/dev/null 2>&1 || true

# 创建分区表和分区
if [ "$BOOT_MODE" = "UEFI" ]; then
    # UEFI + GPT 分区方案
    log "创建GPT分区表"
    parted -s ${TARGET_DISK} mklabel gpt

    log "创建EFI系统分区 (1GB)"
    parted -s ${TARGET_DISK} mkpart primary fat32 1MiB 1025MiB
    parted -s ${TARGET_DISK} set 1 esp on

    log "创建Linux根分区 (剩余空间)"
    parted -s ${TARGET_DISK} mkpart primary ${FILESYSTEM} 1025MiB 100%

    # 格式化分区
    log "格式化EFI分区为FAT32"
    mkfs.fat -F32 ${TARGET_DISK}1

    log "格式化根分区为${FILESYSTEM}"
    if [ "$FILESYSTEM" = "btrfs" ]; then
        mkfs.btrfs -f ${TARGET_DISK}2

        # 创建Btrfs子卷
        mount ${TARGET_DISK}2 /mnt
        btrfs subvolume create /mnt/@
        btrfs subvolume create /mnt/@home
        umount /mnt

        # 使用子卷挂载
        log "挂载分区"
        mount -o subvol=@ ${TARGET_DISK}2 /mnt
        mkdir /mnt/home
        mount -o subvol=@home ${TARGET_DISK}2 /mnt/home
    else
        mkfs.ext4 ${TARGET_DISK}2
        mount ${TARGET_DISK}2 /mnt
        mkdir /mnt/home
    fi

    mkdir /mnt/boot
    mount ${TARGET_DISK}1 /mnt/boot

else
    # BIOS + MBR 分区方案
    log "创建MBR分区表"
    parted -s ${TARGET_DISK} mklabel msdos

    log "创建Linux根分区 (全部空间)"
    parted -s ${TARGET_DISK} mkpart primary ${FILESYSTEM} 1MiB 100%
    parted -s ${TARGET_DISK} set 1 boot on

    # 格式化分区
    log "格式化根分区为${FILESYSTEM}"
    if [ "$FILESYSTEM" = "btrfs" ]; then
        mkfs.btrfs -f ${TARGET_DISK}1

        # 创建Btrfs子卷
        mount ${TARGET_DISK}1 /mnt
        btrfs subvolume create /mnt/@
        btrfs subvolume create /mnt/@home
        umount /mnt

        # 使用子卷挂载
        log "挂载分区"
        mount -o subvol=@ ${TARGET_DISK}1 /mnt
        mkdir /mnt/home
        mount -o subvol=@home ${TARGET_DISK}1 /mnt/home
    else
        mkfs.ext4 ${TARGET_DISK}1
        mount ${TARGET_DISK}1 /mnt
        mkdir /mnt/home
    fi
fi

# 6. 更换镜像源
log "更换为中国镜像源..."
pacman -Sy reflector --noconfirm
reflector --verbose --country 'China' -l 5 -p https --sort rate --save /etc/pacman.d/mirrorlist
reflector --verbose --country 'China' -l 5 -p https --sort rate --save /mnt/etc/pacman.d/mirrorlist

# 7. 安装系统
log "安装基础系统..."

pacstrap /mnt base base-devel linux linux-firmware networkmanager grub\
        vim git sudo man-db man-pages texinfo dhcpcd iwd openssh unzip \
        python3 rust wget npm

if [ "$BOOT_MODE" = "UEFI" ]; then
    pacstrap /mnt efibootmgr
fi
if [ "$FILESYSTEM" = "btrfs" ]; then
    pacstrap /mnt btrfs-progs
fi

if [ "$CPU_VENDOR" = "GenuineIntel" ]; then
    pacstrap /mnt intel-ucode
elif [ "$CPU_VENDOR" = "AuthenticAMD" ]; then
    pacstrap /mnt amd-ucode
fi

# 8. 生成fstab
log "生成fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# 9. 配置系统
log "配置系统..."

# 设置时区（默认为Asia/Shanghai）
arch-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
arch-chroot /mnt hwclock --systohc

# 设置本地化
echo "en_US.UTF-8 UTF-8" > /mnt/etc/locale.gen
echo "zh_CN.UTF-8 UTF-8" >> /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf

# 设置主机名（默认为archlinux）
echo "$HOSTNAME" > /mnt/etc/hostname
cat > /mnt/etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOF

# 设置root密码
echo "$ROOTPASSWD" | arch-chroot /mnt passwd --stdin root

# 添加普通用户
arch-chroot /mnt useradd -m -G wheel $USERNAME
echo "$USERPASSWD" | arch-chroot /mnt passwd --stdin $USERNAME

# 配置sudo
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /mnt/etc/sudoers
# 删除 [multilib] 行的注释符号
sed -i 's/^#\s*\(\[multilib\]\)/\1/' /mnt/etc/pacman.conf
sed -i '/^\[multilib\]$/,/^\[.*\]$/ s/^#\s*\(Include = \/etc\/pacman.d\/mirrorlist\)/\1/' /mnt/etc/pacman.conf
# 在文件末尾添加 archlinuxcn 仓库配置
echo -e '\n[archlinuxcn]\nServer = https://mirrors.aliyun.com/archlinuxcn/$arch' | tee -a /mnt/etc/pacman.conf

arch-chroot /mnt pacman -Syy archlinuxcn-keyring --noconfirm
arch-chroot /mnt pacman -Syy yay --noconfirm

# 配置网络管理器
arch-chroot /mnt systemctl enable NetworkManager
arch-chroot /mnt systemctl enable iwd
arch-chroot /mnt systemctl enable dhcpcd
arch-chroot /mnt systemctl enable sshd

# 10. 安装引导程序
log "安装引导程序..."
if [ "$BOOT_MODE" = "UEFI" ]; then
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot
else
    arch-chroot /mnt grub-install --target=i386-pc ${TARGET_DISK}
fi
sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)\(".*\)/\1 edd=off nomodeset\2/' /mnt/etc/default/grub
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# 11. 清理
log "清理临时文件..."
umount -R /mnt

log "===== 安装完成 ====="
log "请移除安装介质，然后重启系统。"
