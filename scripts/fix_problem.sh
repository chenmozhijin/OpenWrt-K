#!/bin/bash
sed -i 's/^  DEPENDS:= +kmod-crypto-manager +kmod-crypto-pcbc +kmod-crypto-fcrypt$/  DEPENDS:= +kmod-crypto-manager +kmod-crypto-pcbc +kmod-crypto-fcrypt +kmod-udptunnel4 +kmod-udptunnel6/' package/kernel/linux/modules/netsupport.mk #https://github.com/openwrt/openwrt/commit/ecc53240945c95bc77663b79ccae6e2bd046c9c8
sed -i 's/^	dnsmasq \\$/	dnsmasq-full \\/g' ./include/target.mk
sed -i 's/256/1024/' ./target/linux/${{ matrix.target }}/image/Makefile
sed -i 's/^	b43-fwsquash.py "$(CONFIG_B43_FW_SQUASH_PHYTYPES)" "$(CONFIG_B43_FW_SQUASH_COREREVS)"/	$(TOPDIR)\/tools\/b43-tools\/files\/b43-fwsquash.py "$(CONFIG_B43_FW_SQUASH_PHYTYPES)" "$(CONFIG_B43_FW_SQUASH_COREREVS)"/' ./package/kernel/mac80211/broadcom.mk
if [ "$openwrt_tag_branch" = "openwrt-22.03" ] || [[ "$openwrt_tag_branch" =~ ^v22.03.* ]] || [[ "$openwrt_tag_branch" =~ ^23.05.0-rc[1-3]$ ]] ; then
  echo "openwrt版本小于等于23.05.0-rc3，不需要修复brook的go依赖问题"
else
  # https://github.com/openwrt/packages/pull/22251
  if grep -q "^define Package/prometheus-node-exporter-lua-bmx6$" "feeds/packages/utils/prometheus-node-exporter-lua/Makefile"; then
    echo "修复https://github.com/openwrt/packages/pull/22251"
    curl -s -L --retry 6 https://github.com/openwrt/packages/commit/361b360d2bbf7abe93241f6eaa12320d8d83475a.patch  | patch -p1 -d feeds/packages 2>/dev/null
  fi
  echo "修复brook的go依赖问题"
  # 查找所有brook/Makefile文件，并存储到数组中
  brook_makefiles=($(find "$OPENWRT_ROOT_PATH/package" -type f -path "*/brook/Makefile"))
  
  # 遍历数组中的每个路径并处理
  for makefile_path in "${brook_makefiles[@]}"; do
      # 检查Makefile中是否包含PKG_VERSION:=20230606
      if grep -q "PKG_VERSION:=20230606" "$makefile_path"; then
          echo "$makefile_path 包含 PKG_VERSION:=20230606"
          # 使用sed命令进行替换操作
          sed -i 's/PKG_VERSION:=20230606/PKG_VERSION:=ac855e6dbc46f0e085734836556da2cdb9386fa3/g' "$makefile_path"
          sed -i 's/v$(PKG_VERSION)/$(PKG_VERSION)/g' "$makefile_path"
          sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' "$makefile_path"
          echo "$makefile_path 已修复"
          rm -rf $(echo "$makefile_path"|sed 's/Makefile/patches/g')
          echo "$(echo "$makefile_path"|sed 's/Makefile/patches/g') 已删除"
          ls -la $(find $(echo "$makefile_path"|sed 's/Makefile//g') -type d)
      else
          echo "$makefile_path 不包含 PKG_VERSION:=20230606, 跳过修复"
      fi
  done
fi