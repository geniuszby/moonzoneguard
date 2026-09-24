# MoonZoneGuard

[![CI](https://github.com/geniuszby/moonzoneguard/actions/workflows/ci.yml/badge.svg)](https://github.com/geniuszby/moonzoneguard/actions/workflows/ci.yml)

MoonZoneGuard 是用 MoonBit 实现的离线 DNS 区域文件检查与变更审查工具。它在文件进入权威服务器之前报告语法错误、记录冲突、缺少区内目标地址和 SOA serial 问题。核心解析与规则是可复用的 MoonBit 库；命令行使用 `moonbitlang/x/fs` 读取文件。

## 快速开始

安装 [MoonBit 工具链](https://www.moonbitlang.com/download/)，克隆仓库后在项目根目录执行：

```sh
moon update
moon run cmd/main --target js check examples/good.zone example.org.
moon run cmd/main --target js check examples/bad.zone example.org. json
moon run cmd/main --target js diff examples/good.zone examples/good-next.zone example.org.
moon run cmd/main --target js stats examples/good.zone example.org.
moon run cmd/main --target js policy examples/good.zone example.org. examples/review.policy
moon run cmd/main --target js impact examples/good.zone examples/good-next.zone example.org.
moon run cmd/main --target js trace examples/good.zone example.org. docs
moon run cmd/main --target js lookup examples/good.zone example.org. docs A
moon run cmd/main --target js normalize examples/good.zone example.org.
```

`check` 返回 0 表示没有 error，1 表示有 error，2 表示参数或文件错误。warning 不使检查失败。`diff` 在 SOA serial 未按要求前进时返回 1。输出格式：`text`、`json`、`markdown`（差异比较支持前两者）。`origin` 请写为末尾带点的绝对域名。

`diff` 和 `impact` 会先校验变更前后的区域文件；任一文件存在错误时返回诊断，不给出可能误导的变化摘要。可以用 `examples/invalid-soa.zone` 复现这一情况。

## 能检查什么

- `$ORIGIN`、`$TTL`、相对/绝对所有者名称、继承所有者、括号跨行记录、注释和引号文本；
- A、AAAA、NS、SOA、MX、CNAME、PTR、TXT、SPF、SRV、CAA 的基本数据形状；
- 区顶点 SOA/NS、记录重复、同 RRset TTL 一致性、CNAME 与其他数据并存、CNAME 环、区内 NS/MX/SRV 目标的地址记录；
- 两份区域文件的新增、移除、TTL 变化及 SOA serial 的 RFC 1982 序列比较。
- 可选团队策略（TTL 上下限、顶点 NS 数量、邮件 IPv6、禁用记录类型）、记录统计、CNAME 路径追踪、本地区域查询、规范化输出和变更风险摘要。

诊断包含规则代码、严重程度、消息、行列和所有者。JSON 格式适合 CI 消费，其中差异报告的 `serial_order` 字段直接给出 SOA 序列比较结果；Markdown 格式适合贴到代码审查。三个完整操作流程及预期结果见 [SCENARIOS.md](SCENARIOS.md)。

## 运行测试与构建

```sh
moon check --target js
moon test --target js
moon build --target js
moon fmt --check
```

主要算法不依赖文件系统；`cmd/main` 是可执行入口。当前仓库有 134 个自动化测试。CI 在 Linux 上重复以上检查，并执行 [三个使用场景](SCENARIOS.md) 的示例命令。

## 边界

这是本地静态分析器，不请求公共 DNS，也不修改配置文件。`lookup` 只做精确名称和 CNAME 跟踪，不模拟通配符或委派。当前支持常见 Internet zone 记录；不展开 `$INCLUDE`、`$GENERATE`，不完整支持 RFC 1035 的转义八位字节及 DNSSEC 记录数据校验。未知主文件指令会报告错误；部分已识别的高级 RR 类型只做通用解析，不提供完整数据校验。提示区内目标没有 A/AAAA 时只给 warning，因为外部委派和特殊配置需要人工判断。

## 项目与许可证

原创实现，Apache-2.0。运行时文件读取依赖 [`moonbitlang/x`](https://mooncakes.io/moonbitlang/x)，许可证信息见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。协议参考：[RFC 1035](https://www.rfc-editor.org/rfc/rfc1035)、[RFC 1982](https://www.rfc-editor.org/rfc/rfc1982)、[RFC 2181](https://www.rfc-editor.org/rfc/rfc2181)。[申报书](PROJECT_PROPOSAL.md)、[变更记录](CHANGELOG.md)。
