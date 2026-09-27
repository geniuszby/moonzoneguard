# MoonZoneGuard 项目申报书

## 基本信息

- 项目名称：MoonZoneGuard——MoonBit 跨区域 DNS 委派变更审计与发布顺序分析工具
- GitHub 仓库链接：https://github.com/geniuszby/moonzoneguard
- Mooncakes 链接：https://mooncakes.io/docs/geniuszby/moonzoneguard
- 项目方向：网络基础设施、配置可靠性与开发者工具
- 项目类型：原创实现，非移植项目；与已有开源工具的关系见下文。

## 项目简介

MoonZoneGuard 读取多个 DNS 区域文件的新旧快照，检查父区委派 NS、Glue、子区地址与 DS/DNSKEY 摘要关联，分析逐区发布中的中间状态。项目以 MoonBit 实现，采用有界状态枚举和动态规划，输出可行顺序、必要先后约束及阻断反例，供 NS 迁移、密钥轮换与 CI 审查使用。

## 项目方向与通用性说明

面向维护多层权威 DNS 的运维团队、开发者和学习者，可复用于父子区 NS 迁移与多区域配置审查。支持 2–6 个区域、最多 64 个新旧组合；假设每个区一次原子发布。结论是本地保守策略的检查结果，不保证线上可达性；缓存、传播时延、外部 NS 解析及 DNSSEC 验签不在当前范围内。

## 预期使用场景

1. **父子区 NS 迁移：**输入两个区各自的新旧文件，运行 `rollout`；样例指出父区先发布时旧子区缺少新 NS 地址，给出 `G006` 证据并建议先发布子区。
2. **三层区域协同发布：**维护者提交三列文件清单，运行 `plan`；样例枚举 8 个状态，得出唯一顺序“最内层子区→子区→父区”，列出必需先后关系。
3. **DS/DNSKEY 轮换：**输入父区 DS 与子区 key 的新旧快照，运行 `plan`；样例计算 SHA-256 关联，建议子区先加入新 key、保留旧 key，再更新父区 DS。直接替换旧 key 会造成中间失配，返回非零状态阻断 CI。

## 核心功能与本次计划

已完成跨区 NS/Glue/地址检查、DNSKEY 编码与 key tag/SHA-256 DS 匹配、DS 删除降级阻断、状态枚举、顺序计数、约束与反例，并提供文本/JSON CLI。生产 MoonBit 代码排除测试、空行、注释后超过 4000 行，155 项测试通过（含 RFC 4509 标准向量）；已有不少于 10 次有效提交、CI 和可运行样例，0.3.0 发布至 Mooncakes。本次计划完善边界用例、CI 报告接入与维护文档；可复现证据见仓库 `RESUBMISSION_EVIDENCE.md`。

## 原创及开源项目参考说明

已有 [MoonBit DNS Zone Toolkit](https://github.com/lmclmc1/moonbit-dns-zone)（Apache-2.0）提供单区解析、校验、比较与批处理；基础能力与我们重合。本次新增跨区发布模型及 DS/DNSKEY 摘要关联，作为单区检查后的补充；未接入其 API，未移植或复制代码。项目采用 Apache-2.0，通过同许可证的 `moonbitlang/x` 读取文件、`gmlewis/sha256` 计算散列；第三方代码不计入行数，依据 RFC 1982、4034、4509、9471。
