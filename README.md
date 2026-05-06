# Supply Planning Automation Demo

一个基于 **Excel / Power Query / 少量 Python** 的脱敏作品集项目，用于展示我如何将规则驱动的供应规划逻辑整理成可维护、可复用的数据流程。

> 本仓库为个人作品集演示版本。  
> 所有数据、字段名、业务实体、编码和规则均已做脱敏、抽象或简化处理，仅用于展示方法论与实现思路。

---

## 1. 项目简介

这个项目模拟了一个典型的供应规划场景：  
将多张输入表（需求、库存、调整、预测）整合到统一模型中，通过规则计算生成最终输出，用于业务复核和报表展示。

项目的重点不在于复杂算法，而在于：

- Excel 模型结构设计
- Power Query 数据整合
- 规则驱动的分配逻辑
- 面向业务使用者的输出组织
- 文档化和可维护性

---

## 2. 项目目标

本项目主要展示以下能力：

- 将手工 Excel 流程整理成结构化模型
- 将多来源输入表标准化并整合
- 将业务规则拆解为清晰的计算步骤
- 用可复用的方式组织输出结果
- 通过文档说明提升可读性和可交接性

---

## 3. 技术栈

- **Excel**
- **Power Query**
- **Python（少量辅助）**
- **CSV / XLSX**

---

## 4. 输入数据（脱敏版）

本项目使用脱敏后的示例输入，包括但不限于：

- `demand_input`：需求数据
- `inventory_input`：库存数据
- `adjustment_input`：周内调整数据
- `forecast_input`：预测对比数据
- `config`：参数配置表

所有示例数据均为演示用途，不代表任何真实业务信息。

---

## 5. 核心流程

整体流程可概括为：

1. 读取并整理输入表
2. 标准化关键字段
3. 构建基础分析表
4. 按规则执行分配/抵扣逻辑
5. 输出结果表用于复核和展示

---

## 6. 示例业务逻辑（简化版）

该 Demo 中包含的规则示例包括：

- 需求与库存按统一键值匹配
- 不同来源库存按优先级消耗
- 周内调整仅影响当前周期
- 最终结果按统一粒度汇总并与预测值对比

以上逻辑均为脱敏后的抽象表达。

---

## 7. 仓库结构

```text
.
├─ README.md
├─ data/
│  ├─ raw/
│  └─ sample/
├─ docs/
│  ├─ flowchart.png
│  ├─ business_rules.md
│  └─ data_dictionary.md
├─ excel/
│  └─ planning_demo.xlsx
├─ python/
│  └─ helper_scripts.py
└─ outputs/
   └─ sample_output.xlsx


## 8. 我在这个项目中主要做了什么

- 设计输入 / 输出结构
- 梳理 Excel 与 Power Query 的分工
- 将业务规则拆解为可维护步骤
- 组织结果表用于业务复核
- 撰写项目说明、字段说明和流程文档

## 9. 项目特点

这个项目更偏向 **业务规则建模 + Excel 自动化设计**，而不是纯代码项目。  
因此它更关注：

- 结构是否清楚
- 逻辑是否可解释
- 输出是否适合业务使用
- 后续是否容易维护和扩展

## 10. 限制说明

为保护敏感信息，本仓库做了以下处理：

- 使用脱敏或虚构字段名
- 使用示例数据替代真实数据
- 不包含真实业务文件、路径、SQL、截图或内部命名
- 不包含任何生产环境配置

## 11. 后续可扩展方向

- 增加更多参数化配置
- 增加自动校验逻辑
- 增加更清晰的规则说明页
- 将部分 Excel 逻辑进一步迁移为 Python 辅助脚本

## 12. Disclaimer

This repository is a de-identified portfolio project for demonstration purposes only.  
It does not contain proprietary data, confidential business information, or production assets.
