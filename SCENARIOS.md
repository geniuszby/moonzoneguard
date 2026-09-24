# 可复现的使用场景

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

## 场景四：父子区 NS 迁移的发布顺序

计划把 `app.example.org.` 的权威 NS 从 `ns1` 切换为 `ns2`。父子两个区域由不同流程发布，先检查两个可能的中间状态：

```sh
moon run cmd/main --target js rollout examples/rollout-parent-before.zone examples/rollout-parent-after.zone examples/rollout-child-before.zone examples/rollout-child-after.zone example.org. app.example.org.
```

结果是 `child-first`。`parent-updated` 状态会报 `G006`：父区委派已指向 `ns2.app.example.org.`，旧子区还没有它的权威地址；`child-updated` 状态则保留旧 `ns1` 地址，可以通过保守策略检查。每个状态及规则证据可用末尾的 `json` 参数读取；模型不模拟线上缓存和传播时延。

## 场景五：三层区域的发布计划

父区 `example.org.`、子区 `app.example.org.` 和更深一层的 `dev.app.example.org.` 都要更换域内 NS。运行：

```sh
moon run cmd/main --target js plan examples/three-zone.plan
```

程序枚举 8 个状态，找到唯一通过本地规则的顺序：先发布 `dev.app.example.org.`，再发布 `app.example.org.`，最后发布 `example.org.`。报告列出其他状态触发的 `G006` 错误；JSON 输出含可行顺序总数和必须遵守的先后约束。
