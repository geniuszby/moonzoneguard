# 项目申报书

1. **项目名称和 GitHub 仓库地址**  
   MoonZoneGuard：DNS 区域文件离线审查工具。仓库：[github.com/geniuszby/moonzoneguard](https://github.com/geniuszby/moonzoneguard)。

2. **项目简介**  
   DNS 区域文件的语法错误、别名冲突或版本号遗漏，可能在部署后才暴露。MoonZoneGuard 读取本地 zone file，在发布前给出定位到行列的诊断，并比较两个版本的记录变化和 SOA serial。

3. **项目方向与适用场景**  
   开发工具 / 网络基础设施。面向管理自建权威 DNS 的开发者和运维人员；可在本地、代码审查和 CI 中运行，不依赖线上 DNS 查询。

4. **拟实现的核心功能**  
   用 MoonBit 解析常用的 RFC 1035 区域文件写法；校验 A、AAAA、SOA、NS、MX、CNAME、TXT、SRV、CAA 等记录及跨记录约束；识别重复记录、CNAME 冲突、缺失的区内目标地址；输出文本、JSON 和 Markdown 报告；对比两个版本并检查 SOA serial 是否按 RFC 1982 前进。提供命令行、可运行样例、自动化测试、CI 和使用文档。

5. **项目性质**  
   原创项目。解析器、规则、差异分析和命令行均以 MoonBit 自行实现；使用 Apache-2.0 许可。只依赖同许可的 MoonBit 标准库和 `moonbitlang/x` 文件系统组件。参考 RFC 1035、RFC 1982 和 RFC 2181 的公开协议规范，不移植现有项目代码。
