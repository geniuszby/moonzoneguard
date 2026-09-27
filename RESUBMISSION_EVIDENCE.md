# 九月重报：新增范围与可复现证据

初版是单区域文件审查工具，与 [lmclmc1/dns-zone-toolkit](https://github.com/lmclmc1/moonbit-dns-zone) 的解析、校验、比较及查询能力重合。本次保留基础输入层，将新增工作集中在多个区域的关联状态与发布过程，并如实保留这一重合说明。该项目 0.1.0 README 明确将 DNSSEC 校验列在未实现范围中；本项目新增的是有边界的 DS/DNSKEY 摘要关联，不宣称完整 DNSSEC 校验。

| 本次新增核心 | 实际证据 |
| --- | --- |
| 父区委派 NS、Glue 与子区地址关联 | `delegation.mbt`、`delegation_wbtest.mbt` |
| 2–6 区域的有界发布状态模型，最多 64 状态 | `deployment_plan.mbt`、三层示例及测试 |
| 可行顺序计数、必须先后关系、阻断反例 | JSON 字段 `safe_order_count`、`required_precedence`、`counterexample` |
| DS/DNSKEY key tag、SHA-256 摘要匹配与轮换约束 | `dnssec_link.mbt`、RFC 4509 标准向量、独立摘要对照 |
| 错误不会因最终状态正确而被忽略 | 直接替换旧 key 的样例最终匹配，但中间状态失配，返回 1 |

```sh
moon test --target js
moon run cmd/main --target js plan examples/three-zone.plan json
moon run cmd/main --target js plan examples/dnssec-rollover.plan json
moon run cmd/main --target js rollout examples/dnssec-parent-before.zone examples/dnssec-parent-after.zone examples/dnssec-child-before.zone examples/dnssec-child-unsafe.zone example.org. app.example.org.
```

三层样例唯一顺序为内层子区→子区→父区。DS 轮换样例唯一顺序为子区→父区。最后一条反例命令预期返回 1；CI 同时运行成功与失败场景。当前有 155 项 MoonBit 测试，包括标准摘要、错误 Base64、摘要失配、未知摘要类型、Zone Key 标志、双 DS 共存和全部 DS 删除。

本模型假设区域文件逐区原子发布；不处理缓存与传播时延、RRSIG 验签、公钥密码学有效性、NSEC/NSEC3 或在线根信任锚。未知摘要类型明确标为未验证；没有任何已支持的匹配时阻断。SHA-256 通过 Apache-2.0 的包 API 使用，第三方代码不计入项目行数，详见 `THIRD_PARTY_NOTICES.md`。
