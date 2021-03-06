
BUILDER ?= OpenWrt-ImageBuilder-ramips_mt7620n-for-linux-x86_64
SDK ?= OpenWrt-SDK-ramips-for-linux-x86_64-gcc-4.8-linaro_uClibc-0.9.33.2

OPKG_PACKAGES := 6in4 6to4 blkid curl ethtool ip ip6tables-extra ip6tables-mod-nat \
	iperf-mt ipset iptables-mod-conntrack-extra iptables-mod-extra iptables-mod-filter \
	iptables-mod-ipopt iptables-mod-nat-extra iwinfo kmod-crypto-deflate kmod-crypto-des \
	kmod-crypto-ecb kmod-crypto-hmac kmod-crypto-manager kmod-crypto-md4 kmod-crypto-md5 \
	kmod-crypto-pcompress kmod-crypto-sha1 kmod-crypto-sha256 kmod-dnsresolver kmod-fs-cifs \
	kmod-fs-ext4 kmod-fs-hfs kmod-fs-nfs kmod-fs-nfs-common kmod-fs-ntfs kmod-fs-vfat \
	kmod-fuse kmod-gre kmod-ifb kmod-ip6-tunnel kmod-ip6tables-extra kmod-ipip\
	kmod-ipt-conntrack-extra kmod-ipt-extra kmod-ipt-filter kmod-ipt-ipopt kmod-ipt-ipset \
	kmod-ipt-nat-extra kmod-ipt-nat6 kmod-ipt-nathelper-extra kmod-iptunnel kmod-iptunnel4 \
	kmod-iptunnel6 kmod-l2tp kmod-ledtrig-gpio kmod-lib-textsearch kmod-lib-zlib \
	kmod-macvlan kmod-mppe kmod-nfnetlink kmod-nls-cp437 kmod-nls-iso8859-1 kmod-nls-utf8 \
	kmod-pppol2tp kmod-pptp kmod-sched-connmark kmod-sched-core kmod-sit kmod-tun \
	kmod-usb-ohci kmod-usb-printer kmod-usb-storage libcurl libdaemon libevent2 libiwinfo \
	libiwinfo-lua libjson liblua liblzo libmnl libncurses libopenssl libpolarssl \
	libpthread librt libubus-lua libuci-lua lua luci luci-app-firewall luci-app-qos \
	luci-app-samba luci-base luci-i18n-chinese luci-i18n-english luci-lib-json \
	luci-lib-nixio luci-mod-admin-full luci-proto-ipv6 luci-proto-ppp luci-theme-bootstrap \
	ntfs-3g openvpn-openssl ppp-mod-pppol2tp ppp-mod-pptp qos-scripts relayd resolveip \
	samba36-server tc terminfo uclibcxx uhttpd uhttpd-mod-ubus zlib pdnsd pptpd xl2tpd
OPKG_PACKAGES_BL855R :=
PREPARED_TARGETS = .check_ib .patched

# Check each option for selection of packages and dependencies
ifeq ($(FEEDS),1)
	OPKG_PACKAGES += ipset-lists minivtun shadowsocks-libev shadowsocks-tools dnsmasq-full \
		file-storage kmod-proto-bridge kmod-yavlan
	PREPARED_TARGETS += .check_sdk .feeds
endif

define BeforeBuildImage
	mkdir -p $(BUILDER)/dl
	cp -f repo-base.conf $(BUILDER)/repositories.conf
	@[ -n "$(SDK)" -a -f "$(SDK)"/bin/ramips/packages/Packages ] && \
		echo "src ralink file:$(shell cd $(SDK)/bin/ramips/packages; pwd)" >> $(BUILDER)/repositories.conf || :
	mkdir -p $(BUILDER)/target/linux/ramips/base-files/etc
	cp -f opkg.conf $(BUILDER)/target/linux/ramips/base-files/etc/opkg.conf
endef

both: BL-855R

BL-855R: $(PREPARED_TARGETS)
	$(call BeforeBuildImage)
	make -C $(BUILDER) image PROFILE=BL-855R \
		FILES="$(shell cd $(BUILDER); pwd)/target/linux/ramips/base-files" \
		PACKAGES="$(OPKG_PACKAGES) $(OPKG_PACKAGES_BL855R)"

.patched:
	mkdir -p $(BUILDER)/target/linux/ramips/patches-3.10
	cat patches/01-bl855r.patch patches/12-disable-pdnsd.patch > .patching
	patch -d $(BUILDER) -p0 < .patching
	mv .patching .patched

.feeds:
	@cd $(SDK); [ ! -L dl -a -d /var/dl ] && { rmdir dl && ln -s /var/dl; } || :
	@cd $(SDK)/package; [ -d network-feeds ] && { cd network-feeds; git pull; } || git clone https://github.com/rssnsj/network-feeds.git
	make package/ipset-lists/compile V=s -C "$(SDK)"
	make package/shadowsocks-libev/compile V=s -C "$(SDK)"
	make package/shadowsocks-tools/compile V=s -C "$(SDK)"
	make package/minivtun-tools/compile V=s -C "$(SDK)"
	make package/file-storage/compile V=s -C "$(SDK)"
	make package/proto-bridge/compile V=s -C "$(SDK)"
	cd "$(SDK)/bin/ramips/packages" && ../../../scripts/ipkg-make-index.sh . > Packages && gzip -9c Packages > Packages.gz

.check_ib:
	@if ! [ -n "$(BUILDER)" -a -d "$(BUILDER)" ]; then \
		echo "Please specify a valid ImageBuilder directory by adding \"BUILDER=...\"."; \
		echo "Type \"make help\" for more details."; \
		exit 1; \
	fi
.check_sdk:
	@if ! [ -n "$(SDK)" -a -d "$(SDK)/package" ]; then \
		echo "Please specify a valid OpenWrt SDK directory by adding \"SDK=...\"."; \
		echo "Type \"make help\" for more details."; \
		exit 1; \
	fi

# Try extracting ImageBuilder & SDK to current directory
extract:
	tar jxvf /var/dl/$(BUILDER).tar.bz2
	tar jxvf /var/dl/$(SDK).tar.bz2

help:
	@echo "Usage:"
	@echo "  make BUILDER=.... [RALINK=1] [FEEDS=1]     build OpenWrt firmware for this board"
	@echo "Options:"
	@echo "  BUILDER=<directory>        specify a valid ImageBuilder directory"
	@echo "  SDK=<directory>            specify a valid OpenWrt SDK directory"
	@echo "  FEEDS=1                    build and install Shadowsocks, minivtun, kmod-proto-bridge, kmod-yavlan"

clean: .check_ib
	make clean -C $(BUILDER)
	@if [ -e .patched ]; then \
		patch -R -d $(BUILDER) -p0 < .patched; \
		rm -vf .patched; \
	fi
	[ -n "$(SDK)" -a -d "$(SDK)"/bin/ramips ] && rm -rf "$(SDK)"/bin/ramips/* || :
