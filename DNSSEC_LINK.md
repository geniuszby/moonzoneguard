# DS/DNSKEY 摘要关联与发布状态

本功能是跨区域发布模型中的静态关联检查。它不会将无效签名的区域认证为安全，也不验证公网 DNSSEC 信任链。

## 检查范围

当父区在子区原点发布 DS 时，解析子区顶点 DNSKEY 的数字字段与 Base64 公钥，要求 protocol 为 3。按 RFC 4034 将规范化的小写 ASCII 所有者名称编码为无压缩 wire name，再将 DNSKEY RDATA 编为 flags、protocol、algorithm、public key，计算 key tag 与 SHA-256 摘要。匹配必须同时满足 key tag、algorithm 和完整摘要，不能仅依靠可能碰撞的 key tag。

仅处理 DS digest type 2（SHA-256）。DNSKEY 必须设 Zone Key 标志、未设 REVOKE，才能作为匹配候选。算法 1 的特殊 key tag 不支持；不验证签名算法、公钥曲线点/RSA 模数或 RRSIG 的有效性。其他 digest type 会明确标为未检查；如果没有任何已支持的匹配，保守策略阻断发布。多个 DS 中允许一个匹配与其他未匹配项共存，但保留警告。

## 规则与证据

| 规则 | 结果 | 含义 |
| --- | --- | --- |
| S100 | note | DS 与 DNSKEY 匹配，附两份文件的记录位置 |
| S101 | error | DS 数字、十六进制或摘要长度不合法 |
| S102 | error | DNSKEY 字段或 Base64 不合法/不支持 |
| S103 | warning | DS 摘要类型未支持 |
| S104 | warning | 一条 SHA-256 DS 未找到匹配 key |
| S105 | error | 当前状态没有已支持的 DS/DNSKEY 匹配 |
| S106 | warning | 子区有 DNSKEY，但父区无 DS，未检查摘要关联 |
| S107 | error | 变更删除全部 DS，保守策略阻断信任降级 |

S107 是发布策略，主动退场 DNSSEC 应采用另行人工审查的流程。S100 仅说明摘要关联存在，不能代替 RRSIG 验证或 resolver 的认证结果。

## 可运行案例

```sh
moon run cmd/main --target js plan examples/dnssec-rollover.plan json
moon run cmd/main --target js rollout examples/dnssec-parent-before.zone examples/dnssec-parent-after.zone examples/dnssec-child-before.zone examples/dnssec-child-unsafe.zone example.org. app.example.org.
```

第一条命令得到唯一顺序 `app.example.org.` → `example.org.`。子区先预发布新 key、保留旧 key，随后父区替换 DS；父区先更换 DS 会触发 S105。第二条命令用只含新 key 的子区直接替换旧 key，两个中间状态都触发 S105，返回 1；虽然最终摘要匹配，也不能跳过中间状态。之后移除旧 key 是新的发布阶段，需重新提供快照审查。

案例公钥来自 RFC 8032 的公开 Ed25519 测试向量，无私钥或真实服务凭据；它们不是完整签名区域。另用 RFC 4509 的 DNSKEY/DS 向量验证 key tag 60485 与完整 SHA-256 摘要，Ed25519 样例摘要与 .NET SHA256 独立计算结果对照。

参考：[RFC 4034](https://www.rfc-editor.org/rfc/rfc4034)、[RFC 4509](https://www.rfc-editor.org/rfc/rfc4509)、[RFC 8032](https://www.rfc-editor.org/rfc/rfc8032)。SHA-256 使用 Apache-2.0 的 `gmlewis/sha256@0.17.32` 包；本仓库不重新实现密码学散列算法。
