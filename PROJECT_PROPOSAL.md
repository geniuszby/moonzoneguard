# MoonZoneGuard 项目申报书

## 基本信息

- 项目名称：MoonZoneGuard——MoonBit 实现的 DNS 区域文件离线审查工具
- GitHub 仓库链接：https://github.com/geniuszby/moonzoneguard
- Mooncakes 链接：https://mooncakes.io/docs/geniuszby/moonzoneguard
- 项目方向：网络基础设施、开发者工具与配置可靠性分析
- 是否为移植项目：否，原创项目

## 项目简介

MoonZoneGuard 是以 MoonBit 为主要实现语言的 DNS 区域文件离线审查工具。在配置发布前，它解析本地 zone file，定位语法及记录冲突，并比较版本变化和 SOA 序列号。项目提供命令行、文本与 JSON 报告、可复现样例、自动化测试及 CI；运行时不查询线上 DNS，也不修改原始文件。

## 项目方向与适用场景

项目方向为网络基础设施、开发者工具和配置可靠性分析，面向维护自建权威 DNS 的开发者、运维人员和学习者。首版聚焦常见 Internet 区域文件的只读分析，不提供在线递归解析、自动修复或完整 DNSSEC 校验。

## 预期使用场景

1. **上线前检查：**运维人员对拟部署的区域文件运行 `check`。正确样例返回 0；错误样例返回带规则编号、行列和所有者的 JSON 诊断，并以非零状态阻止 CI 发布。
2. **变更代码审查：**开发者用 `diff` 比较发布前后文件，核对 `www` 地址由 `192.0.2.30` 改为 `192.0.2.31`，确认 SOA 序列号前进；再用 `impact` 查看地址变更的审查优先级。缺少 SOA 的候选文件会被拒绝比较。
3. **团队策略审查：**维护者加载 `review.policy`，检查 TTL、顶点 NS 数量和邮件目标 IPv6 地址；样例产生 `P103` 告警。随后用 `lookup` 沿 `docs` 的 CNAME 找到目标 A 记录，确认别名指向。

## 拟实现的核心功能

- 解析 `$ORIGIN`、`$TTL`、相对名称、继承所有者、跨行记录、注释和引号文本；
- 校验 A、AAAA、SOA、NS、MX、CNAME、TXT、SRV、CAA 等记录及跨记录约束，报告行列位置和严重程度；
- 识别重复记录、CNAME 冲突与环、区内 NS/MX/SRV 目标缺少地址记录、Null MX 和 SPF/CAA 配置问题；
- 比较区域文件版本，识别新增、删除和 TTL 变化，并按 RFC 1982 检查 SOA 序列号；
- 提供团队策略、区域统计、别名追踪、本地查询、规范化输出和变更影响摘要；
- 当前 MoonBit 实现和测试合计超过 4000 行，131 项测试全部通过；GitHub 仓库已有不少于 10 次有效提交，配置了 GitHub Actions CI，版本 0.1.0 已发布至 Mooncakes。

## 原创及开源项目参考说明

MoonZoneGuard 为原创项目，不是移植项目；解析器、规则和差异分析以 MoonBit 独立实现，未复制第三方 DNS 工具代码。协议行为参考 RFC 1035、RFC 1982、RFC 2181、RFC 7208、RFC 7505 和 RFC 8659。项目采用 Apache-2.0 许可证；文件读取使用同许可证的 MoonBit 官方扩展包 `moonbitlang/x@0.4.49`，不包含外部素材或数据集。
