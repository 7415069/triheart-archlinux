# TriHeart Linux

![TriHeart Archlinux 图形安装器横幅](installer/branding/banner.png)

**TriHeart Installer** 基于 Debian Installer（d-i）构建，用它的图形向导安装 Arch Linux。从专用 ISO 启动后，沿用 d-i 的语言、键盘、网络、分区、账户和安装流程。目标系统使用对应架构的 Arch 仓库和签名密钥环，默认安装 KDE Plasma。

## 构建 ISO

在 macOS 或 Linux 上启动 Docker，然后在项目目录运行 `./scripts/build-iso`。宿主机使用 `curl` 下载构建输入，构建容器负责验签，并调用 Debian 13 的原生 `debian-cd` Makefile 构建 netinst，再通过本地 udeb 仓库加入 Arch 适配。

```sh
git clone https://github.com/7415069/triheart-archlinux.git
cd triheart-archlinux
./scripts/build-iso --help
```

| 虚拟机或目标平台 | 构建命令 | 默认输出 | 目标系统仓库 |
| --- | --- | --- | --- |
| ARM64，例如 Apple Silicon 上的 ARM64 虚拟机 | `./scripts/build-iso arm64` | `dist/triheart-archlinux-arm64.iso` | [Arch Linux ARM](https://archlinuxarm.org/platforms/armv8/generic) |
| Intel 或 AMD 的 x86_64 机器 | `./scripts/build-iso amd64` | `dist/triheart-archlinux-x86_64.iso` | Arch Linux |

无参数运行、`-h` 和 `--help` 都会列出有效参数。第二个参数可指定输出路径，便于保留虚拟机正在使用的镜像。

```sh
./scripts/build-iso arm64 ./dist/triheart-installer-test-arm64.iso
```

构建需要联网。默认使用 Debian 13.7.0，`TRIHEART_DEBIAN_VERSION` 可指定 Debian 13 的其他点版本；其 d-i 内核必须与包集合中的驱动 ABI 一致，否则验证失败。`TRIHEART_DEBIAN_MIRROR`、`TRIHEART_DEBIAN_CD_MIRROR` 和 `TRIHEART_ARCH_MIRROR` 分别设置 Debian 归档、发行 ISO 根目录和 Arch 引导包镜像。安装时的 Arch 软件源由向导单独选择。

### 原生构建链与逐步对照

每次构建先校验 Debian 官方 netinst 的签名和校验和，将其软件包集合用作有限的本地构建镜像，再从经过 `InRelease` 验证的 Debian 归档补齐少量构建工具包及同版 d-i `cdrom` 输入。使用容器中 Debian 13 的 `debian-cd`（源码脚本随记录保留），执行 `make status` 和 `make official_images`，重新生成软件包选择、镜像树、BIOS/UEFI 启动结构及 ISO。官方 netinst 用于提供包集合，不直接作为重打包模板。

安装介质的 udeb 依赖选择、驱动、固件打包和组件索引由 `debian-cd` 负责。Arch 适配包通过其 `LOCAL` / `LOCALDEBS` 扩展加入，Arch 引导环境通过 `DISC_END_HOOK` 放入 `/triheart/`。运行时保留原生 `cdrom-detect`、`load-cdrom`、`cdrom-retriever` 和 `anna`，从 `/cdrom` 提取 udeb；项目不再自建检索器或把全部 udeb、Arch 引导环境塞入 initrd。引导内核与上游输入逐字节比较，图形 initrd 的原始文件和符号链接逐项校验；仅替换两个品牌图片，追加字体与 fontconfig 配置，并允许 debian-cd 按原生流程追加无障碍固件。

中文字体通过独立的 fontconfig 配置使用 Noto Sans CJK SC，保留原生字号、拉丁字体和 `gtk-set-font`。当前上游缺少旧字体 `AR PL ShanHeiSun Uni`，语言选择器因此使用默认 `DejaVu Sans`；配置同时覆盖这两个入口，避免中文回退到日文字形或 Motoya 标点。构建会从最终 ISO 提取字体和规则，使用 Pango 实际排版普通正文、粗体、中文标点及 cdebconf 对齐空格，检查最终字体与缺失字形，结果保存在 `04-iso/font-layout-*.json` 和 `rendered-fonts.tsv`。

```sh
# 原生 Debian netinst 对照：不加入 Arch 适配，不下载 Arch 引导环境
./scripts/build-iso amd64 --profile debian

# Arch 基础系统及控制台：复用原生向导和分区，安装 Arch 的基础软件与 GRUB
./scripts/build-iso amd64 --profile arch-base

# 完整 Arch + KDE，默认配置
./scripts/build-iso amd64
```

对照镜像默认输出 `dist/triheart-debian-netinst-x86_64.iso`，基础系统镜像输出 `dist/triheart-arch-base-x86_64.iso`。ARM64 使用相同参数，将 `amd64` 换为 `arm64`。本地构建的 Debian 对照镜像标记为 Unofficial。

### 构建记录与空间清理

每次构建创建独立的 `dist/builds/<架构>-<UTC 时间戳>.<随机后缀>/`，终端输出阶段进度。`BUILD.md` 索引记录，`stages.tsv` 标识失败阶段，`build.log` 保留完整输出。

**默认仅在 ISO 验证、原子发布并复核最终校验和之后清理中间产物。** 删除本次下载、展开的包镜像、debian-cd 工作树、临时 initrd、组件二进制和构建目录中的重复 ISO，最终 ISO 只保留在指定输出路径。失败构建保留现场。脚本不新增共享下载缓存，也不清理其他项目的 Docker 数据；已有 `dist/downloads/` 可只读复用。

| 路径 | 成功后保留的内容 |
| --- | --- |
| `builder.txt`、`build.log`、`stages.tsv` | Docker 镜像 ID、平台及各阶段日志 |
| `01-sources/` | 来源、签名、密钥、项目和 debian-cd 源码快照、所修改 udeb 的原始脚本/模板/依赖 |
| `02-netinst/` | 原生 netinst 的配置、启动结构、udeb 索引和校验记录 |
| `02-components/`、`03-initrd/` | 适配包版本、索引、镜像清单及内核/图形 initrd 记录 |
| `04-iso/` | 最终介质的打包命令、启动结构、udeb 和固件清单、文件校验记录 |
| `ARTIFACTS.SHA256SUMS` | 清理前各阶段文件的历史校验和 |
| `SHA256SUMS` | 清理后实际保留文件的校验和（不含仍在写入的日志/阶段表） |
| `published.tsv`、`cleanup.tsv` | 最终 ISO 的绝对路径、SHA-256 及清理清单 |

在构建目录执行 `shasum -a 256 -c SHA256SUMS` 或 `sha256sum -c SHA256SUMS` 可复核记录。需要完整中间产物时显式添加 `--keep-work`：

```sh
./scripts/build-iso amd64 --keep-work
```

## 在虚拟机中安装

1. 创建与 ISO 架构匹配的虚拟机，添加一块空白虚拟磁盘，启用 UEFI 并关闭 Secure Boot。Apple Silicon 上的 VirtualBox 可使用 Linux ARM64、VMSVGA、4 GB 内存和 NAT，挂载 ISO 时跳过无人值守安装。
2. 挂载 ISO 并启动。选择原生 **Graphical install**，进入 d-i 图形向导。保留上游菜单顺序和安装交互；安装器使用 TriHeart 标识与标题，中文通过 fontconfig 别名使用 Noto Sans CJK，localechooser 的字体选择脚本保持不变。
3. 按向导设置网络、地区、账户和磁盘。分区使用 d-i 原生 `partman`。目标磁盘、分区方案、文件系统和挂载点由用户选择并确认。UEFI 安装需要挂载目标磁盘的 EFI 系统分区。
4. 在镜像选择页选定 Arch 镜像，然后在软件选择页按需勾选 **SSH 服务器** 或 **开发工具**。KDE Plasma 和 KDE 应用套件默认安装。
5. 安装完成后弹出 ISO，从目标磁盘启动并登录 Plasma。

EFI 安装名称和 GRUB 菜单发行版名称均为 `TriHeart Archlinux`。选择更新 EFI 启动项时，安装器核对当前 ESP 的 GPT 标识与引导文件路径，启用对应启动项并将其放到启动顺序首位，保留其他系统的启动项；固件拒绝或未保留启动顺序时报告失败。旧 Debian 引导项仍存在时，不能仅凭引导文件安装成功就认定固件会启动新系统。ISO 的 GRUB 菜单主题和底层终端均不加载背景品牌横幅，避免选择安装后切换到内核时残留图片；保留原生菜单顺序、布局和操作，图形向导横幅不变。最终介质检查同时覆盖这两处背景设置。

### 安装介质与联网要求

- **安装器组件**和 Arch 引导环境随 ISO 提供。`debian-cd` 选择并打包同版 udeb，`cdrom-retriever` / `anna` 从原生介质索引加载，不需要从网络获取安装器组件。每次构建会校验 ISO 内索引引用的全部 udeb，并检查驱动内核 ABI。
- **网卡驱动和固件**沿用 Debian 13 d-i 的内核和同版驱动，固件由 `debian-cd` 的 `FORCE_FIRMWARE` 功能打包，由原生 `hw-detect` 加载。需要更多硬件支持时更新整套上游输入。目标系统通过 Arch 安装自己的 `linux-firmware` 和无线监管数据库。
- **目标系统软件包**在安装时从所选 Arch 滚动仓库下载并校验签名，包括基础系统、KDE 和 GRUB。当前 ISO 需要联网完成安装。完整离线版待实现，计划使用 `triheart-archlinux-<arch_version>-<架构>.iso` 命名。
- **安装进度**在基础系统和桌面安装时都区分下载、校验、安装和安装后任务。下载行显示已下载包数、本次下载总包数和按包数计算的百分比。pacman 提供合计速率时，以逗号附在百分比后。安装阶段会显示正在处理的软件包名称。确认下载失败时会自动重试一次，失败对话框显示软件包工具报告的错误。

### 首次登录后的桌面

- KDE Plasma Wayland、Plasma 登录管理器、KDE 应用套件、Firefox、LibreOffice 和 Noto 字体。
- Discover 的软件包与 Flatpak 支持、NetworkManager、PipeWire 音频、CUPS 打印和蓝牙。系统托盘使用 Plasma 音量控件，默认软件包清单排除 KMix。
- 选择中文地区时安装浏览器和办公套件的相应语言包，并为向导创建的用户配置 Fcitx 5 中文输入法。
- 选择开发工具时安装 `base-devel`、OpenJDK 8 和 11，默认使用 Java 11。选择 SSH 服务器时安装并启用 OpenSSH。

## 移植实现

d-i 继续负责图形前端、步骤调度、硬件探测、网络、分区和问答。Arch 适配位于 [`installer/bootstrap-base/`](installer/bootstrap-base/) 和 [`installer/ports/`](installer/ports/)。基础系统步骤在 `partman` 挂载的 `/target` 上运行 `pacstrap`，软件安装步骤调用 `pacman`，引导步骤根据现有分区结果生成 initramfs 并配置 GRUB。安装器镜像列表由验签后的 Arch 引导环境中的 `/etc/pacman.d/mirrorlist` 与项目内置列表合并生成。 [Debian Installer 组件文档](https://d-i.debian.org/doc/internals/ch03.html)

具备 `dpkg-deb` 和对应架构 GCC 的 Linux 构建环境可以运行 `./scripts/build-component`，单独生成 `dist/bootstrap-base_0.1.0_amd64.udeb`。

## 虚拟机验收记录

本次迁移使用新的 debian-cd 构建链。构建检查包括 BIOS/UEFI 结构、上游内核与图形 initrd 原始文件一致性、udeb 文件校验、驱动 ABI、适配包入盘和介质校验和。构建通过不代表已完成虚拟机安装、目标系统重启或实体 T430 / Ventoy 验收；这些需逐项对照验证。

2026-11-07：amd64 和 arm64 均已通过新构建入口的完整构建、内容校验和自动清理。QEMU 中原生 netinst 对照已通过 BIOS 图形启动；新的 amd64 镜像已通过 UEFI 图形启动、原生 `anna` 从 ISO 加载全部九个适配包及 DHCP 获取地址，停在主机名设置页。ARM64 字体修正镜像已在无硬盘的 VirtualBox 临时虚拟机中通过 UEFI 图形启动和简体中文显示验收，确认前端加载 Noto 常规与粗体，保留原生 `DejaVu Sans 9` 设置；本次字体修改未重新执行完整安装重启。字体回归、现场诊断和截图位于 `dist/validation/font-fix-20261107/`。

下表记录此前版本的完整安装验收范围。

| 平台 | 已验证的安装路径 |
| --- | --- |
| Apple Silicon 上的 VirtualBox，ARM64 UEFI | 使用引导式 ext4 分区完成联网安装，移除 ISO 后进入 Plasma Wayland。验证了简体中文输入、CUPS、PipeWire、Flathub 和中文用户目录。另行验证了复用 Btrfs 分区后重试安装、保留 SSH 选项启动，以及 UEFI 回退引导。 |
| x86_64 UEFI 虚拟机 | 早期版本通过已签名软件包的测试缓存完成精简系统安装。验证了独立 ext4 `/home`、GRUB 启动、普通用户登录、DHCP 和 `pacman -Syu`。 |

待端到端验收的路径包括 x86_64 空盘联网安装 KDE、传统 BIOS 引导，以及加密、LVM 和 RAID 分区方案。

## 许可证

仓库根目录提供 [MIT 许可证](LICENSE)。ISO 内的 Debian、Arch Linux、Arch Linux ARM 及第三方组件适用各自的上游许可证。

### 2026-11-07 启动修复与品牌配置

ARM64 虚拟机重分区后，旧的 TriHeart UEFI 条目仍引用原 ESP 的分区 GUID。Arch GRUB 2.16 按相同加载器路径识别已登记条目，因而没有更新它。适配组件在 GRUB 安装后核对当前 GPT 分区 GUID 和加载器路径，必要时由官方 `efibootmgr` 补登记当前 ESP，保留其他启动项，并尊重用户关闭 NVRAM 更新的选择。修复已在原虚拟机验证，系统成功进入 Plasma 登录界面；重复登记校验没有新增条目。

`debian-cd` 上游脚本保持不变并进行源码校验。品牌通过其发行名称、介质标签、背景图配置及独立 d-i 输入覆盖层实现。两个提供的 SVG 与项目的 `logo.svg` 内容相同，继续复用项目现有横幅和背景图。菜单顺序保持原生：amd64 的图形安装在第一项，ARM64 在第二项。
