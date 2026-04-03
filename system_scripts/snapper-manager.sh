#!/bin/bash

# ============================================
# Snapper 快照管理脚本 - 交互式菜单版本
# 功能: 创建、删除、列出快照
# ============================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 配置
SNAPPER_CONFIG="system"  # 改为你的配置名称

# 检查 snapper 配置
check_config() {
    if ! sudo snapper -c "$SNAPPER_CONFIG" list &> /dev/null; then
        echo -e "${YELLOW}⚠ Snapper 配置 '$SNAPPER_CONFIG' 不存在${NC}"
        read -p "是否创建默认配置？(y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo snapper -c "$SNAPPER_CONFIG" create-config /
            echo -e "${GREEN}✓ 配置创建成功${NC}"
        else
            echo -e "${RED}请先创建 snapper 配置${NC}"
            exit 1
        fi
    fi
}

# 显示菜单
show_menu() {
    clear
    echo -e "${PURPLE}╔════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║     ${CYAN}Snapper 快照管理工具${PURPLE}               ║${NC}"
    echo -e "${PURPLE}╠════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC}                                        ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}  ${GREEN}1${NC}) 列出所有快照                       ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}  ${GREEN}2${NC}) 创建新快照                         ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}  ${GREEN}3${NC}) 删除快照                           ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}  ${GREEN}4${NC}) 更新 GRUB 菜单                     ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}  ${GREEN}0${NC}) 退出                               ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}                                        ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -ne "${YELLOW}请选择操作 [0-4]: ${NC}"
}

# 列出快照
list_snapshots() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                    Snapper 快照列表${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    
    printf "${YELLOW}%-6s %-12s %-28s %s${NC}\n" "编号" "类型" "创建时间" "描述"
    echo "-----------------------------------------------------------------------"
    
    sudo snapper -c "$SNAPPER_CONFIG" --csvout --separator $'\t' --no-headers list --columns number,type,date,description |
    while IFS=$'\t' read -r num type date_str desc; do
        # 根据类型设置颜色
        case "$type" in
            "single") color="$GREEN" ;;
            "pre") color="$CYAN" ;;
            "post") color="$BLUE" ;;
            *) color="$NC" ;;
        esac
        
        printf "${color}%-6s %-12s %-28s %s${NC}\n" "$num" "$type" "$date_str" "$desc"
    done
    
    # 显示统计
    total=$(sudo snapper -c "$SNAPPER_CONFIG" --csvout --no-headers list | wc -l)
    echo "-----------------------------------------------------------------------"
    echo -e "${GREEN}总计: ${total} 个快照${NC}"
    
    echo ""
    read -p "按 Enter 键返回菜单..."
}

# 创建快照
create_snapshot() {
    echo -e "\n${BLUE}[创建新快照]${NC}"
    
    read -p "请输入快照描述 (可选，直接回车使用默认): " description
    
    if [ -z "$description" ]; then
        description="手动备份 $(date '+%Y-%m-%d %H:%M:%S')"
    fi
    
    echo -e "\n${YELLOW}正在创建快照...${NC}"
    echo -e "描述: ${GREEN}$description${NC}"
    
    if sudo snapper -c "$SNAPPER_CONFIG" create --description "$description"; then
        # 获取刚创建的快照编号
        snapshot_id=$(sudo snapper -c "$SNAPPER_CONFIG" list | tail -1 | awk '{print $1}')
        echo -e "\n${GREEN}✓ 快照创建成功！${NC}"
        echo -e "快照编号: ${YELLOW}#$snapshot_id${NC}"
    else
        echo -e "\n${RED}✗ 快照创建失败！${NC}"
    fi
    
    echo ""
    read -p "按 Enter 键返回菜单..."
}

# 删除快照
delete_snapshot() {
    echo -e "\n${BLUE}[删除快照]${NC}"
    
    # 先显示快照列表
    echo -e "\n${CYAN}当前快照列表:${NC}"
    sudo snapper -c "$SNAPPER_CONFIG" list --columns number,date,description | tail -n +2 | head -20
    
    echo ""
    read -p "请输入要删除的快照编号: " snapshot_id
    
    if [ -z "$snapshot_id" ]; then
        echo -e "${RED}错误: 未输入编号${NC}"
        read -p "按 Enter 键返回..."
        return
    fi
    
    # 检查快照是否存在
    if ! sudo snapper -c "$SNAPPER_CONFIG" list | grep -q "^[[:space:]]*$snapshot_id "; then
        echo -e "${RED}错误: 快照 #$snapshot_id 不存在${NC}"
        read -p "按 Enter 键返回..."
        return
    fi
    
    # 获取快照信息
    snapshot_info=$(sudo snapper -c "$SNAPPER_CONFIG" list | grep "^[[:space:]]*$snapshot_id ")
    description=$(echo "$snapshot_info" | awk '{for(i=4;i<=NF;i++) printf "%s ", $i; print ""}')
    
    echo -e "\n${YELLOW}即将删除:${NC}"
    echo -e "  编号: ${RED}#$snapshot_id${NC}"
    echo -e "  描述: $description"
    
    echo ""
    read -p "确认删除此快照？(y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if sudo snapper -c "$SNAPPER_CONFIG" delete "$snapshot_id"; then
            echo -e "\n${GREEN}✓ 快照 #$snapshot_id 已删除${NC}"
        else
            echo -e "\n${RED}✗ 删除失败！${NC}"
        fi
    else
        echo -e "\n${YELLOW}已取消删除${NC}"
    fi
    
    echo ""
    read -p "按 Enter 键返回菜单..."
}

# 更新 GRUB 菜单
update_grub_menu() {
    echo -e "\n${BLUE}[更新 GRUB 菜单]${NC}"
    echo -e "${YELLOW}正在重新生成 GRUB 配置，这样 snapper 快照启动项才能同步到引导菜单。${NC}"

    if command -v update-grub &> /dev/null; then
        grub_command="sudo update-grub"
    elif command -v grub-mkconfig &> /dev/null; then
        grub_cfg="/boot/grub/grub.cfg"

        if [ -d /boot/grub2 ]; then
            grub_cfg="/boot/grub2/grub.cfg"
        fi

        grub_command="sudo grub-mkconfig -o $grub_cfg"
    else
        echo -e "\n${RED}错误: 未找到 update-grub 或 grub-mkconfig${NC}"
        echo -e "请先安装并配置 GRUB / grub-btrfs。"
        echo ""
        read -p "按 Enter 键返回菜单..."
        return
    fi

    echo -e "执行命令: ${CYAN}$grub_command${NC}"
    echo ""

    if eval "$grub_command"; then
        echo -e "\n${GREEN}✓ GRUB 菜单已更新${NC}"
    else
        echo -e "\n${RED}✗ GRUB 菜单更新失败${NC}"
    fi

    echo ""
    read -p "按 Enter 键返回菜单..."
}

# 主函数
main() {
    # 检查依赖
    if ! command -v snapper &> /dev/null; then
        echo -e "${RED}错误: 未安装 snapper${NC}"
        echo -e "请运行: ${YELLOW}sudo pacman -S snapper${NC}"
        exit 1
    fi
    
    # 检查配置
    check_config
    
    # 主循环
    while true; do
        show_menu
        read choice
        
        case $choice in
            1)
                list_snapshots
                ;;
            2)
                create_snapshot
                ;;
            3)
                delete_snapshot
                ;;
            4)
                update_grub_menu
                ;;
            0)
                echo -e "\n${GREEN}再见！${NC}"
                exit 0
                ;;
            *)
                echo -e "\n${RED}无效选项，请重新选择${NC}"
                sleep 1
                ;;
        esac
    done
}

# 运行主函数
main "$@"
