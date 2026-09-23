# 三个可复现的使用场景

以下命令在仓库根目录执行，需先安装 MoonBit 工具链并运行 `moon update`。所有输入文件都在 `examples/`，工具不会访问公网 DNS 或修改它们。

## 场景一：权威 DNS 配置上线前检查

运维人员准备部署 `example.org.` 区域文件，先运行：

```sh
moon run cmd/main --target js check examples/good.zone example.org.
moon run cmd/main --target js check examples/bad.zone example.org. json
```

第一条命令显示 `0 error(s), 0 warning(s)` 并返回 0。第二条命令返回 1，JSON 中包含错误计数及每项诊断的规则编号、行列位置和所有者。样本展示了无效 IPv4、CNAME 与地址并存、CNAME 环以及缺失的区内 NS/MX 目标地址。维护者可据此修正文件，再在 CI 中重新检查。

## 场景二：代码审查中的 DNS 变更评估

开发者将当前版本与拟发布版本并排比较：

```sh
moon run cmd/main --target js diff examples/good.zone examples/good-next.zone example.org.
moon run cmd/main --target js impact examples/good.zone examples/good-next.zone example.org.
```

`diff` 显示 SOA serial 从 `2026092301` 前进到 `2026092302`，`www` 的 A 记录从 `192.0.2.30` 改为 `192.0.2.31`；共 4 条记录级变化、0 个错误。`impact` 把服务地址变更标为中等审查优先级，并提示确认消费者和缓存影响。若候选文件缺少 SOA，可用以下命令验证工具会拒绝继续比较并返回 1：

```sh
moon run cmd/main --target js diff examples/good.zone examples/invalid-soa.zone example.org.
```

## 场景三：团队策略和邮件配置审查

团队要求 TTL 范围、至少两个顶点 NS，并要求区内邮件目标提供 IPv6 地址：

```sh
moon run cmd/main --target js policy examples/good.zone example.org. examples/review.policy
moon run cmd/main --target js lookup examples/good.zone example.org. docs A
```

第一条命令返回 0，同时给出 `P103` 警告：`mail.example.org.` 没有 AAAA 记录。策略告警供人工审查，不会被误当成 DNS 语法错误。第二条命令沿 `docs` 的 CNAME 找到 `www.example.org.`，显示其 A 记录 `192.0.2.30`，便于确认别名变更的目标。
