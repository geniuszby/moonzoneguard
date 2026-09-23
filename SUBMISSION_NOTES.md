# 九月黑客松报名材料备忘

- 参赛者：GitHub 用户名 `geniuszby`；姓名、联系方式等个人信息在官方问卷中由本人填写。
- 公开仓库：https://github.com/geniuszby/moonzoneguard
- 一页申报书：[PROJECT_PROPOSAL.md](PROJECT_PROPOSAL.md)
- 现有基础：MoonBit 解析器、校验器、差异分析、命令行、样例、文档、测试和 CI 已在本仓库公开。可运行 `moon run cmd/main --target js check examples/good.zone example.org.` 验证。
- 本次开发内容：完善 DNS 区域文件解析与静态检查、团队策略、版本差异与 SOA serial、报告格式及命令行使用体验。
- 预期目标与技术路线：以纯 MoonBit 库负责解析和规则，薄命令行层负责文件读取；用源位置诊断、单元测试、样例和 GitHub Actions 验证。项目保持离线、只读。
- 功能、测试与文档：见 [README.md](README.md)、[`examples/`](examples/) 和 [CI](.github/workflows/ci.yml)。
- 项目性质：原创 MoonBit 实现，不是移植项目；第三方依赖和许可证见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

实际报名与验收材料以本次九月黑客松飞书问卷及后续官方通知为准。
