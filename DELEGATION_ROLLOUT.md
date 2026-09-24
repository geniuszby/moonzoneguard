# 父子区发布顺序检查

`rollout` 分析一个父区与其下属子区的四份本地区域文件：父区变更前、父区变更后、子区变更前、子区变更后。输入是文件快照，不是线上 DNS 查询结果。命令可用于代码审查与 CI 预检。

```sh
moon run cmd/main --target js rollout \
  examples/rollout-parent-before.zone \
  examples/rollout-parent-after.zone \
  examples/rollout-child-before.zone \
  examples/rollout-child-after.zone \
  example.org. app.example.org. json
```

## 状态模型

| 状态 | 父区 | 子区 | 含义 |
| --- | --- | --- | --- |
| `baseline` | 旧 | 旧 | 当前配置 |
| `parent-updated` | 新 | 旧 | 父区先发布后的中间状态 |
| `child-updated` | 旧 | 新 | 子区先发布后的中间状态 |
| `final` | 新 | 新 | 全部发布完成 |

两种候选路径分别是 `baseline → parent-updated → final` 和 `baseline → child-updated → final`。某路径的三个状态没有本地错误、且两个区的变更前置检查通过时，输出 `parent-first`、`child-first` 或 `either-order`。否则输出 `no-safe-order`，CLI 返回 1。JSON 中保留每个状态、输入版本、规则编号、文件来源及行号，便于重现反例。缺失的记录没有源文件行号，以 `0` 表示。

## 多区域计划

`plan` 从清单读取 2 至 6 个区域。每行三个空格分隔的字段：`区域原点 变更前文件 变更后文件`，可用 `#` 注释；文件路径相对于运行命令时的当前目录。样例：

```sh
moon run cmd/main --target js plan examples/three-zone.plan
moon run cmd/main --target js plan examples/three-zone.plan json
```

程序按区域原点选择清单中最近的上级区域，枚举所有新旧快照组合，最多 64 个状态。一次发布只切换一个区域；动态规划搜索由全旧状态到全新状态的路径。结果给出一条可行顺序、可行顺序总数、所有可行顺序共同要求的先后约束，以及可以作为第一步的区域。没有可行顺序时，输出从可达状态跨入错误状态的反例。三层示例只有一个可行顺序：`dev.app.example.org.` → `app.example.org.` → `example.org.`。

## 当前规则

- `G001`：子区原点必须严格位于父区之下。
- `G002`：父区在子区原点必须有委派 NS。
- `G003`：子区顶点必须有 NS。
- `G004`：父区委派 NS 与子区顶点 NS 集合不同，作为警告。
- `G005`：父区为位于子区内的 NS 缺少 A/AAAA Glue，作为错误。
- `G006`：被父区委派的域内 NS 在子区快照中缺少权威 A/AAAA，作为保守发布策略的错误。
- `G007`：父区 Glue 与子区地址没有共同值，作为保守发布策略的错误。

另复用单区比较器检查父区和子区各自的变更及 SOA serial；其错误会阻止推荐发布顺序。NS 集合不一致可能是迁移过程的一部分，因此只给警告。`G006` 与 `G007` 是本项目的保守策略判断，不应解释为 DNS 协议必然无法解析。

## 与已有 MoonBit 项目的关系

[MoonBit DNS Zone Toolkit](https://github.com/lmclmc1/moonbit-dns-zone) 已提供单份区域文本的解析、校验、查询、差异比较与批处理，发布早于 MoonZoneGuard。MoonZoneGuard 的原有单区域能力与其明显重合；新增 `rollout` 以两个区域各自的新旧快照为输入，检查跨区委派关系及两种发布顺序中的中间状态。两项目均采用 Apache-2.0，但本仓库没有复制对方源代码，也没有把该项目计入本仓库代码行数。后续可将其解析结果接入相同的跨区审计模型，目前尚未实现该适配器。

## 边界

每个区文件被视为一次原子发布。当前不模拟缓存和 TTL 等待、权威服务器传播、DNSSEC 验证或外部 nameserver 地址解析。多区域模式只处理清单中的最近父子关系，不推断未提供区域的真实部署状态。`pass` 表示此有界模型内未发现错误，不代表实际域名始终可达。参考：[RFC 9471 的域内 Glue 分类](https://www.rfc-editor.org/rfc/rfc9471)、[RFC 1982 的序列号比较](https://www.rfc-editor.org/rfc/rfc1982)。
