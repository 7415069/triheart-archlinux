# TriHeart Linux

TriHeart Linux 将 Debian Installer（d-i）移植为 Arch Linux 的安装程序。安装器名为 **TriHeart Installer**。从专用安装介质启动后，用户通过 d-i 的图形向导安装 Arch Linux。

## 项目需求

- 沿用 d-i 图形向导的完整步骤、顺序和交互方式，包括语言、键盘、网络、分区、用户、软件选择、安装进度和错误处理。需要适配 Arch 的模块在原有步骤中接入。
- d-i 的界面、组件调度、硬件探测、分区等组件默认复用上游实现。检查各组件与 Debian 目标系统绑定的操作，优先通过现有扩展点在对应步骤改用 Arch 工具，保留该步骤的输入、进度和错误反馈。
- 复用 `partman` 的自动与手动分区流程。目标磁盘、分区方案、文件系统和挂载点由用户在原生向导中选择。
- 使用 Arch 官方软件仓库、密钥环及软件包签名验证。从安装基础系统到安装后更新，目标系统采用 Arch 的软件包和配置方式，由 `pacman` 管理。
- 交付可直接启动图形安装器的 ISO，并提供安装介质的构建说明。

## 移植边界

安装器运行环境与目标系统分别处理。原型沿用 d-i 的专用运行环境和 `udeb` 组件机制，通过 d-i 的扩展点接入 Arch 安装后端。

| d-i 环节 | 移植方向 |
| --- | --- |
| 图形前端与步骤调度 | 复用 `cdebconf`、`main-menu` 和现有模板，适配 Arch 特有选项 |
| 硬件、网络与分区 | 复用现有组件，由 `partman` 按用户确认的方案完成分区、格式化和挂载 |
| 基础系统 | 通过 `base-installer` 的替代组件机制接收 `partman` 挂载好的 `/target`，用 Arch 工具安装系统并反馈进度和结果 |
| 软件源与软件选择 | 将面向目标系统的 `apt-setup`、`apt-install`、`pkgsel` 和 `tasksel` 职责迁移到 Arch 镜像源、软件组合与 `pacman` |
| 系统配置与引导 | 将向导输入应用到 Arch 的用户、语言、时区与网络配置，并根据 `partman` 的分区和挂载结果处理 `fstab`、initramfs 和引导配置 |

按操作职责选择 [Arch 安装工具](https://wiki.archlinux.org/title/Installation_guide)。例如，用 `pacstrap` 安装基础系统，用 `pacman` 安装目标软件包，并适配对应的包名、执行顺序、签名验证与失败处理。组件接入和调度沿用 [d-i 组件机制](https://d-i.debian.org/doc/internals/ch03.html)。

## 虚拟机验收

在 x86_64 UEFI 虚拟机上已验证一条完整的安装路线。通过 d-i 图形向导选择目标磁盘、引导式分区的独立 `/home` 方案及最小系统。`partman` 创建 EFI 分区、ext4 根分区、交换分区和 ext4 `/home`。向导完成后移除安装介质和测试缓存盘，虚拟机通过 GRUB 从目标磁盘启动。向导创建的普通用户可以登录，`/home` 正确挂载，系统通过 DHCP 联网，`pacman -Syu` 成功同步官方仓库。

本次安装使用仅供测试的官方签名包缓存。过程中补建了 d-i 环境的 `/dev/shm`，随后在原步骤重试成功。开发 ISO 已包含修复。待验证项包括直接用修复版 ISO 从空盘联网安装、手动分区和其他文件系统、加密与 LVM/RAID、桌面软件组合、传统 BIOS 以及下载和校验失败的交互。当前的 Arch GRUB 安装路径要求关闭 Secure Boot。

在 Apple Silicon 的 VirtualBox 7.2.22 上，ARM64 图形向导已通过引导式 ext4 分区完成联网安装，移除 ISO 后从目标盘进入 Plasma Wayland。简体中文账户首次登录可在 Firefox 和 LibreOffice Writer 中使用 Fcitx 5 输入中文。已检查 CUPS、PipeWire、Flathub 和中文用户目录，蓝牙服务已启用。

在原有 Btrfs 分区上也曾从软件配置失败处重试，保留 SSH 选项后成功启动到 KDE 登录界面。另在独立测试盘上验证了固件能在旧启动项失效时通过 `EFI/BOOT/BOOTAA64.EFI` 加载 GRUB。

## 开发构建

开发镜像在 d-i 的原有步骤中使用 `pacstrap` 安装基础系统，使用 `pacman` 安装 KDE Plasma 和 KDE 应用套件。系统托盘使用 Plasma 自带的音量控件，安装清单排除 KMix。桌面默认配备 Firefox、LibreOffice、Noto 字体、Discover 的软件包与 Flatpak 支持、PipeWire 音频、CUPS 打印和蓝牙。选择中文地区时，安装对应的浏览器和办公套件语言包，并为向导创建的账户配置 Plasma Wayland 下的 Fcitx 5 输入法。

软件选择页提供 SSH 服务器和开发工具两个附加选项。开发工具包含 OpenJDK 8 和 11，默认使用 Java 11。系统使用 Plasma 登录管理器，并按分区结果安装 Arch 的 GRUB。账户继续使用 `user-setup` 的原生问答，网络配置沿用 `netcfg` 生成的 NetworkManager 配置。构建时验证 Debian 图形镜像、被适配的 `udeb` 和 Arch bootstrap 的来源。

图形向导选中中文后使用随 ISO 打包的 Noto Sans CJK。软件安装页用 d-i 的原生进度条显示 pacman 的下载、校验、安装和安装后任务。下载百分比按已完成包数除以待下载总包数计算，百分比后显示当前软件包下载的合计速率。安装阶段显示当前软件包名称。

启动 Docker 后，在项目目录执行统一入口。Apple Silicon 的 VirtualBox 使用 `arm64`，Intel 或 AMD 虚拟机使用 `amd64`。

```sh
./scripts/build-iso arm64
```

直接运行 `./scripts/build-iso` 会显示用法。指定架构后，入口自动准备构建容器，由宿主机下载输入，再由容器验签和打包。运行 `./scripts/build-iso arm64` 默认生成 `dist/triheart-archlinux-arm64.iso`，运行 `./scripts/build-iso amd64` 默认生成 `dist/triheart-archlinux-x86_64.iso`。也可以指定独立的输出路径，便于保留虚拟机当前挂载的 ISO。

```sh
./scripts/build-iso arm64 ./dist/triheart-installer-test-arm64.iso
```

### 查看构建过程

每次运行创建独立的 `dist/builds/<架构>-<时间戳>.<编号>/`。终端实时显示阶段进度，`BUILD.md` 是产物索引，`build.log` 和 `stages.tsv` 记录完整日志及每一步的状态。构建失败时可以查看已产生的文件和失败阶段。

| 目录 | 本次构建的产物 |
| --- | --- |
| `01-sources/` | 上游 ISO、签名和验签结果、Arch 引导包、原始 udeb、下载来源和项目源码快照 |
| `02-components/` | 生成的 udeb、组件版本、镜像清单和打包后的 Arch 引导环境 |
| `03-initrd/` | 上游 initrd、覆盖层目录与归档、合并后的 initrd、ARM64 引导菜单修改前后的文件 |
| `04-iso/` | 最终 ISO、实际运行的 xorriso 命令、引导结构以及从 ISO 提取文件的比对结果 |

在本次构建目录执行 `shasum -a 256 -c SHA256SUMS` 可以复核记录里的输入和产物。使用 `04-iso/xorriso-command.txt` 中的命令可以从保留的输入重新打包，执行前将 `-outdev` 改为新的文件名。构建记录通过硬链接复用已下载的大文件和最终 ISO 的磁盘数据。

在 amd64 虚拟机中选择 **Install** 运行标准图形向导，或从 **Advanced options → Expert install** 逐步检查。图形横幅显示 **TriHeart Archlinux** 和 `installer/branding/logo.svg` 中的三心标识。

向导按国家或地区列出目标架构的镜像，选中的地址优先用于 `pacstrap` 和目标系统的 `pacman`。构建时从验签后的 Arch Linux 或 Arch Linux ARM 引导环境提取各自的 `pacman-mirrorlist`，ARM64 同时加入已验证可访问的国内 HTTPS 镜像。

构建时按 Debian 签名索引校验 `udeb`，将适用于镜像内核的安装器组件及其索引打包进 ISO。安装时由 d-i 的 `anna` 从本地加载分区工具、驱动等组件，并核对软件包哈希。构建记录中的 `01-sources/udebs/bundled.tsv` 列出打包的组件。

ISO 自带启动向导和运行安装工具所需的 Arch 引导环境。基础系统、KDE 和 GRUB 在安装时从所选滚动仓库下载，使用该镜像当时同步的软件包版本。包含完整软件包快照的离线安装仍待实现，离线镜像使用 `triheart-archlinux-<arch_version>-<架构>.iso` 命名。

已有 `dpkg-deb` 的环境可直接运行 `./scripts/build-component`，单独生成 `dist/bootstrap-base_0.1.0_amd64.udeb`。

### ARM64 开发镜像

`dist/triheart-archlinux-arm64.iso` 使用 Debian trixie ARM64 的 d-i 图形向导。目标系统使用 [Arch Linux ARM 的 AArch64 仓库](https://archlinuxarm.org/platforms/armv8/generic)、签名密钥环和 `linux-aarch64`。已在 Apple Silicon 的 VirtualBox 7.2.22 通过 UEFI 启动并验证三心横幅和镜像选择。

在 Apple Silicon 的 VirtualBox 中创建 Linux ARM64 虚拟机，使用 UEFI、VMSVGA、4 GB 内存和 NAT。挂载 ISO，跳过 VirtualBox 无人值守安装，启动菜单会进入 **TriHeart Installer (ARM64)**。需要试分区时，在虚拟机里添加一块新的空白虚拟磁盘。
