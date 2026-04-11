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

# 解析快照编号输入，支持空格、逗号和范围
parse_snapshot_selection() {
    local input="$1"
    local normalized_input token start end snapshot_id
    local -A seen_ids=()

    PARSED_SNAPSHOT_IDS=()
    INVALID_SNAPSHOT_TOKENS=()

    normalized_input=$(echo "$input" | tr ',' ' ')

    for token in $normalized_input; do
        if [[ $token =~ ^[0-9]+-[0-9]+$ ]]; then
            start=${token%-*}
            end=${token#*-}

            if (( start > end )); then
                INVALID_SNAPSHOT_TOKENS+=("$token")
                continue
            fi

            for ((snapshot_id = start; snapshot_id <= end; snapshot_id++)); do
                if [[ -z ${seen_ids[$snapshot_id]} ]]; then
                    PARSED_SNAPSHOT_IDS+=("$snapshot_id")
                    seen_ids[$snapshot_id]=1
                fi
            done
        elif [[ $token =~ ^[0-9]+$ ]]; then
            if [[ -z ${seen_ids[$token]} ]]; then
                PARSED_SNAPSHOT_IDS+=("$token")
                seen_ids[$token]=1
            fi
        else
            INVALID_SNAPSHOT_TOKENS+=("$token")
        fi
    done
}

# 删除快照
delete_snapshot() {
    echo -e "\n${BLUE}[删除快照]${NC}"
    
    # 先显示快照列表
    echo -e "\n${CYAN}当前快照列表:${NC}"
    sudo snapper -c "$SNAPPER_CONFIG" list --columns number,date,description | tail -n +2 | head -20
    
    echo ""
    read -p "请输入要删除的快照编号（支持 12 15 18-25 或 12,15,18-25）: " snapshot_input

    if [ -z "$snapshot_input" ]; then
        echo -e "${RED}错误: 未输入编号${NC}"
        read -p "按 Enter 键返回..."
        return
    fi

    parse_snapshot_selection "$snapshot_input"

    if [ ${#INVALID_SNAPSHOT_TOKENS[@]} -gt 0 ]; then
        echo -e "${RED}错误: 以下输入格式无效: ${INVALID_SNAPSHOT_TOKENS[*]}${NC}"
        read -p "按 Enter 键返回..."
        return
    fi

    if [ ${#PARSED_SNAPSHOT_IDS[@]} -eq 0 ]; then
        echo -e "${RED}错误: 未解析出有效编号${NC}"
        read -p "按 Enter 键返回..."
        return
    fi

    snapshot_data=$(sudo snapper -c "$SNAPPER_CONFIG" --csvout --separator $'\t' --no-headers list --columns number,type,date,description)
    valid_snapshot_ids=()
    missing_snapshot_ids=()

    for snapshot_id in "${PARSED_SNAPSHOT_IDS[@]}"; do
        if [ "$snapshot_id" = "0" ]; then
            missing_snapshot_ids+=("$snapshot_id")
            continue
        fi

        snapshot_info=$(echo "$snapshot_data" | awk -F'\t' -v target="$snapshot_id" '$1 == target {print; exit}')

        if [ -n "$snapshot_info" ]; then
            valid_snapshot_ids+=("$snapshot_id")
        else
            missing_snapshot_ids+=("$snapshot_id")
        fi
    done

    if [ ${#missing_snapshot_ids[@]} -gt 0 ]; then
        echo -e "${YELLOW}以下快照不存在或不可删除，已跳过: ${missing_snapshot_ids[*]}${NC}"
    fi

    if [ ${#valid_snapshot_ids[@]} -eq 0 ]; then
        echo -e "${RED}错误: 没有可删除的快照${NC}"
        read -p "按 Enter 键返回..."
        return
    fi

    echo -e "\n${YELLOW}即将删除以下 ${#valid_snapshot_ids[@]} 个快照:${NC}"
    printf "${YELLOW}%-6s %-12s %-28s %s${NC}\n" "编号" "类型" "创建时间" "描述"
    echo "-----------------------------------------------------------------------"

    for snapshot_id in "${valid_snapshot_ids[@]}"; do
        snapshot_info=$(echo "$snapshot_data" | awk -F'\t' -v target="$snapshot_id" '$1 == target {print; exit}')
        IFS=$'\t' read -r num type date_str description <<< "$snapshot_info"

        case "$type" in
            "single") color="$GREEN" ;;
            "pre") color="$CYAN" ;;
            "post") color="$BLUE" ;;
            *) color="$NC" ;;
        esac

        printf "${color}%-6s %-12s %-28s %s${NC}\n" "$num" "$type" "$date_str" "$description"
    done
    
    echo ""
    read -p "确认删除这些快照？(y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if sudo snapper -c "$SNAPPER_CONFIG" delete "${valid_snapshot_ids[@]}"; then
            echo -e "\n${GREEN}✓ 已删除 ${#valid_snapshot_ids[@]} 个快照: ${valid_snapshot_ids[*]}${NC}"
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
