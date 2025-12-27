# Strategy-Aggregator-V0

---

## Description

Strategy Aggregator 是一个模块化、可扩展的 DeFi 资产管理协议，旨在将用户资金在多个收益策略（如 Aave V3、Compound V3、Fluid 等）之间进行统一管理、估值与调度，实现透明、可验证、可组合的链上资产配置。

---

## Project Status/项目进度

本项目当前处于 核心功能已完成策略扩展、安全和权限控制打磨阶段。

## 此版本为V0版本

## 已完成从用户Deposit->铸造份额->push fund to strategy->earning->harvest fund back to vault->burn shares and redeem的流程

✅ 已完成

核心架构
• Vault / Comptroller / Strategy 解耦架构
• Vault 份额模型（Share-based accounting）
• 多策略并行资产管理
• Strategy 可插拔设计（统一接口）

资产估值 & 会计模型
• Vault 内资产 + 策略在外资产统一 NAV / GAV 计算
• Strategy 级别自定义估值逻辑（calcGav()）
• 基于预言机的 USD 计价（Chainlink / Pyth）
• 处理 decimals / WAD 精度与截断问题
• 修复策略资产未计入 NAV 导致的份额错误问题

策略集成
• Aave V3 USDC Lender
• supply / withdraw
• aToken 利息累积验证
• 实测 APY ≈ 官方 APY（误差 < 0.1%）
• Compound V3 (Comet) USDC Lender
• supply / withdraw
• 内部记账余额验证
• 年化收益与链上利率一致
• 多策略并行分配
• 资金按比例分配（如 70% Aave + 30% Compound）
• 收益聚合正确性验证

测试体系
• Foundry 主网 fork 测试
• 时间推进（warp + roll）
• 多用户不同时间入场 / 出场测试
• 同时入场对比测试（验证 APY 一致性）
• 利率波动对收益差异的归因验证
• 精度断言（assertApproxEqRel / Abs）

费用 & 参数系统
• Deposit Fee / Redeem Fee
• Performance Fee / Manager Fee
• bit-packed VaultConfig（节省 storage / gas）
• 参数 setter + 权限控制测试

---

## 已集成策略

• AAVE V3 Lender
• Compound Lender
• Fluid Lender
