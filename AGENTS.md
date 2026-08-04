# 协作约定（务必遵守）

## 添加/集成任何新软件前，必须完成的依赖核查

在动手改编译配置之前，必须依次完成以下步骤，并把结论明确告知用户：

1. **完整阅读官方指引**
   - 官方 README、文档、安装/依赖说明、常见问题（GitHub 官方仓库优先）。
   - 不止看"装什么包"，还要看官方对内核、权限、运行时组件的明确要求。

2. **完整阅读相关源码**
   - 包/插件的 Makefile：编译期依赖、构建工具链要求。
   - 内核相关代码：用到的 eBPF 挂载类型（tc/cgroup/xdp/kprobe 等）、内核模块、
     命名空间、系统调用、路由/防火墙特性——逐项映射到内核 Kconfig 开关。
   - 运行时部分：需要哪些命令、文件权限、rpcd ACL、UCI 配置、LuCI 页面、数据文件。

3. **输出完整依赖清单并先确认**
   - 分四类列出：编译期依赖 / 内核配置 / 内核模块 / 运行时包与权限。
   - 与用户确认无误后再修改工作流，不要边编边补。

4. **把关键依赖写进编译硬校验**
   - 关键内核开关、分区、包选择等必须"缺项即编译失败"，不允许发布后再发现。

5. **不把"刷机实测"当作发现依赖的手段**
   - 依赖应在源码/文档阶段查全；实测只用于最终验证，不用于发现缺失项。

## 其他约定

- 与用户使用中文交流。
- 新想法/新改动先向用户确认，再动手。
- 本仓库同时产出三个版本：dae+natcap、dae 无 natcap、官方原版；
  分区/内核/依赖差异见工作流注释。
- 编译启用工具链 + ccache 缓存，三个变体共用，由主变体保存。
- 内核依赖清单（dae/daed 数据面）：
  `BPF / BPF_SYSCALL / BPF_JIT / DEBUG_INFO / DEBUG_INFO_BTF /
   NET_SCH_INGRESS / NET_CLS_BPF / NET_ACT_BPF / NET_CLS_ACT /
   CGROUPS / CGROUP_BPF / NAMESPACES / NET_NS /
   IP_MULTIPLE_TABLES / IPV6_MULTIPLE_TABLES / VETH /
   XDP_SOCKETS / XDP_SOCKETS_DIAG / KPROBES / KPROBE_EVENTS / BPF_EVENTS /
   NETKIT`
  （`NETKIT` 已开启：dae 使用 Netkit 性能模式，不再降级 veth）
