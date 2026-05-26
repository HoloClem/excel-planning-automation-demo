## ‑ Supply Demand Alignment & Gap Analysis Framework 

SDA Framework 项目阶段总结（当前有效版本） 

版本说明： 本文档基于项目团队最新确认口径整理，反映当前 Excel + Power Query demo 的完整主逻辑，包含 FDD 模块与 Open PO 模块的正式集成。适用于 Introduction / README / 项目说明文档。 

## 1. 项目背景与目标 

本项目的目标是基于 Allocation、Inventory、AGI、PRF 和 FDD，构建一个可以在 Excel + Power Query 中刷新运行的 demo，用来估算未来各周的 production need，并将模型 推导结果分别与 PRF 和 FDD 进行对比。 

当前阶段的重点是将 Excel + Power Query 的自动刷新、参数化结构和可维护的表结构落 地，形成一个业务可读、逻辑可追踪、后续可扩展的分析框架。 

最终输出粒度为 week + scode + odm_desc，核心输出字段包括 predicted_qty、 prf_qty、gap_vs_prf、FDD_OpenQty 和 gap_vs_openFDD。 

## 2. 当前项目总体流程 

当前版本的主线可概括为： 

**Allocation → US / non-US demand** 拆分 → **V4 routing** （ **US07** 优先覆盖 **US demand** ， 溢出由 **CN02** 承接）→ **Lead time** 偏移（ **US07** 取 **week N+1** ， **CN02** 取 **week N** ）→ **AGI rollback → pcode inventory coverage → scode inventory coverage → PRF compare → FDD compare** 

模型并不是直接从"当前库存"出发去看剩余需求，而是先利用本周 AGI 将当前库存回推为 本周开始时的 Beginning BOH，再从这个周初库存状态出发，模拟需求对库存的逐步消耗， 最终得到需要生产的数量。 

模型输出同时与 PRF（工厂计划）和 FDD（ODM 供给承诺）进行两层独立对比，分别 回答"工厂计划够不够"和"ODM 承诺够不够"两个问题。 

## 3. 数据输入与核心表结构 

## 3.1 主要输入层 

|3.1主要输入层||
|---|---|
|表名|说明|
|00_control|参数控制表|
|01_alloc_raw<br>|Allocation原始数据（gross demand起<br>点）|
|02_us_rate_fnal|US rate最终版本|
|MM_US_Rate|物料主数据（含PTI_CONSOLIDATED标<br>记）|
|PRF|工厂计划 benchmark|
|04 in-week_AGI|当周 AGI数据|
|inventory_raw|统一库存源表|
|FDD_OpenQty|FDD供给承诺数据|



## 3.2 主要计算层 

|3.2主要计算层||
|---|---|
|表名|说明|
|03_alloc_pcode_level|Allocation按全局us_rate split与US07<br>plant原始量取 MAX进行 US/non-US拆分|
|04_alloc_pcode|pcode层聚合（week +pcode + scode）|
|05_agi_pcode_wide|AGIpcode宽表|
|06_pcode_inventory_current_wide|pcode当前库存宽表|
|07_pcode_boh_base|pcode BOH基准|
|08_pcode_roll|pcode层滚动库存覆盖（完全隔离）|
|09_scode_roll|scode层滚动库存覆盖（完全隔离，含<br>Open PO）|
|10_prf_long|PRF长表|
|12_open_po|Open PO按scode + site + week汇总，早<br>于 PRF首周的 PO自动归入首周|



## 3.3 最终输出层 

|3.3最终输出层||
|---|---|
|表名<br>|说明|
|11_fnal_compare|最终对比输出（含gap_vs_prf和<br>gap_vs_openFDD）|



整个表结构体现了"输入层 → 计算层 → 输出层"的清晰分层，便于后续调试、解释和扩 展。 

## 4. Allocation 路由与 US rate 逻辑 

Allocation 在当前版本中代表全部原始需求（gross demand），是模型起点。 

## 4.1 Plant-based routing（核心变更） 

**Step 1** ：在 pcode + demand_group 粒度拆分需求 us_qty = allocation_qty × us_rate non_us_qty = allocation_qty × (1 - us_rate) 

**Step 2** ：在 week + scode 层聚合 AMR_Need = Σ us_qty（所有 pcode） NON_AMR_Need = Σ non_us_qty（所有 pcode） 

**Step 3** ：US07 优先覆盖 US 需求 - 若 AMR_Need ≤ US07_Alloc → CN02_US_Alloc = 0 - 若 AMR_Need > US07_Alloc → CN02_US_Alloc = AMR_Need − US07_Alloc 

**Step 4** ：非 US 需求全归 CN02 CN02_NON_US_Alloc = NON_AMR_Need 最终输出三个量： US07_Alloc、CN02_US_Alloc、CN02_NON_US_Alloc 

## 4.2 PTI_CONSOLIDATED override 

PTI_CONSOLIDATED = "100%" 的 scode，其 us_rate 在 US_Rate 表中已被设为 100%， 因此全局 split 时自动 us_alloc = total_alloc，无需单独 override 分支。 

## 4.3 US rate 拆分方式 

US rate 在 pcode + demand_group 粒度逐行拆分数量： us_qty = allocation_qty × us_rate non_us_qty = allocation_qty - us_qty 拆分后的 us_qty / non_us_qty 在 scode 层汇总， 再 通过 V4 routing 决定 US07 和 CN02 各自承担多少。 旧版以 weighted_us_rate 为核心的 路径、以及全局 split + MAX 的路径均已废弃。 

US rate 的使用方式是在 pcode + demand_group 粒度先拆分数量： 

```
us_allocation_qty = allocation_qty × us_rate
non_us_allocation_qty = allocation_qty - us_allocation_qty
```

模型的主逻辑是"先算 qty，再往上聚合"，旧版以 weighted_us_rate 为核心的路径已废弃。 

## 4.4 Lead Time 偏移与首周叠加 

US07 运输周期较长，需提前一周发运。模型中同一交付窗口： - CN02 → 取 week N 的数 据 - US07 → 取 week N+1 的数据 

首周（当前周 N）为特殊情况： US07_Net_Alloc = **week N** 的 **US07 allocation** + **week N+1** 的 **US07 allocation** （因当前周已在进行中，US07 需同时完成本周发货和下周备 货） 

从第二周起恢复正常，US07 只取 week N+1 单周。 

在 PQ 中通过将 US07 的 week 减 1 实现偏移， 输出为 delivery_week，使下游公式统 一查同一 week。 

## 4.5 Plant 合并 

NL02 与 CN02 统一合并，以 CN02 名义展示。 PQ 中通过 ReplaceValue 将 NL02 替换 为 CN02， 下游所有筛选使用 plant <> "US07" 兜住。 

## 5. AGI 逻辑（当前正式版本） 

AGI 在当前版本中的定位：不再用于扣减当前周 demand，而是用于根据当前库存回推出 本周开始时的初始库存，即 Beginning BOH。 

当前周 demand 仍然使用完整 gross allocation，不再生成 agi_qty_applied、 open_total_allocation_qty 等旧字段。 

BOH 回推公式： 

本周开始时初始库存 `=` 当前时点库存 `+` 本周 `WTD AGI` 

当前采用的核心近似假设是：本周内影响 pcode 可用库存变化的主要 movement 先只看 AGI，其他 movement 暂时不纳入模型。由于 SQL 端已经只取本周 AGI，所以在 Excel / Power Query 中不需要再重复判断 current_week。 

## 6. pcode 层库存覆盖逻辑 

## 6.1 Pool 定义 

|**Plant**|**Pool**|
|---|---|
|US07|TWpool|
|CN02|CNpool|



## 6.2 Beginning BOH 

```
begin_us07_inventory_qty = current_us07_inventory_qty + us07_agi_wtd_qty
begin_cn02_inventory_qty = current_cn02_inventory_qty + cn02_agi_wtd_qty
```

## 6.3 覆盖规则（当前最新 — 完全隔离） 

当前版本采用完全隔离规则，不存在任何跨 plant 补位： 

|**Demand**来源|可消耗库存|能否跨 **plant**|
|---|---|---|
|US07的所有demand（US<br>only）|只吃US07库存|不能|
|CN02的所有demand（US<br>+ non-US）|只吃CN02库存|不能|



任何一侧库存不足时，直接穿透为 net need，不允许调用另一侧库存。 

## ⚠ 旧版 **"non-US demand** 先吃 **CN02** ，不够再吃 **US07** 剩余 **"** 的单向补位规则已废弃。 

## 6.4 pcode 层 Excel 滚动公式 

pcode 层的滚动覆盖通过 Excel 公式实现（数据按 pcode → week 排序）： 

|列|含义|公式逻辑|
|---|---|---|
|end_us07_inventory|US07期末库存|MAX(0,可用库存- us_alloc)|
|end_cn02_inventory|CN02期末库存|MAX(0, 可用库存- nonus_alloc)|



US07_net_need US07 穿透净需求 MAX(0, us_alloc - 可用库存) CN02_net_need CN02 穿透净需求 MAX(0, nonus_alloc - 可用库存) 

其中"可用库存"= 如果上一行是同一 pcode → 上一行的 end inventory；否则 → begin BOH（新 pcode 开始滚动）。 

## 6.5 pcode 层核心输出 

- end_us07_inventory_qty 

- end_cn02_inventory_qty 

- US07_net_need（穿透到 scode 层后对应 PTI） 

- CN02_net_need（穿透到 scode 层后对应 PEGA） 

## 7. 从 pcode 到 scode 的映射与聚合 

当前模型中，一个 pcode 对应唯一 scode，但一个 scode 可以对应多个 pcode。因此 在 pcode 层完成库存覆盖后，必须将剩余需求映射回 scode，并在更高层级上进行聚合 （sum）。 

## 聚合映射： 

|聚合映射：|||
|---|---|---|
|**pcode**层输出|聚合到 **scode**层|**odm_desc**|
|US07_net_need|pti_gross_need_qty|PTI Taiwan NPSG|
|CN02_net_need|pega_gross_need_qty|Pegatron NPSG|



## 8. scode 层库存覆盖逻辑 

## 8.1 scode inventory pool 

|8.1 scode inventory pool||
|---|---|
|工厂代码|对应 **ODM**|
|TW02|PTI|
|CN04|PEGA|



## 8.2 覆盖规则（完全隔离） 

PTI 只吃 PTI scode inventory。PEGA 只吃 PEGA scode inventory。两边严格不能互相 

cover。 

scode 层不是统一共享库存池，而是按工厂严格分隔的第二层覆盖逻辑。PTI 和 PEGA 两 边的计算完全独立。 

## 8.3 Open PO 模块（在途供给增强） 

Open PO 模块是对现有 scode 层库存覆盖逻辑的增强。原逻辑仅以 BOH（期初库存）作 为每周可支配量，未纳入已下单但尚未到货的在途供给。加入 Open PO 后，每周可支配 库存 = BOH + Open PO，避免因忽略在途量而误判缺货。 

## **Open PO** 定义 

`Open PO Qty = Quantity (PO) - SUM(Quantity Reduced (MRP)) PO` 下单总量      该 `PO` 最新快照下所有 `LA` 行的累计已发运量 

- Quantity (PO) 是每个 Purchasing Document Number 的固定值，不累加 

- Quantity Reduced (MRP) 按该 PO 的所有 LA 行求 SUM 

- 差值 > 0 即为尚未到货的 Open PO 

## 早期 **Open PO** 聚合规则 

Open PO 的交货周（week）可能早于模型的分析起始周（即 PRF 删掉当周后的最小 week）。 这些"早到但尚未入库"的 PO 仍然是有效的在途供给，不应丢弃。 处理方式： 在 12_open_po 查询中，将 week < MinPRFWeek 的行的 week 统一替换为 MinPRFWeek， 再按 scode + week 重新聚合（SUM）。这样所有早期 Open PO 的数量 会自动汇入模型的第一周， 被 09_scode_roll 的首周行读取。 MinPRFWeek 动态取自 10_prf_long 的最小 week（即 PRF 删掉当周后的起始周）， 每周三 PRF 更新后会自动 跟着变化，无需手动维护。 

## **Open PO** 周次聚合与动态首周对齐 

12_open_po 中的 MinPRFWeek 动态取自 10_prf_long 的最小 week。 由于 10_prf_long 在 PQ 内部已删掉 PRF 原始表的最小周（当周无参考意义）， 其输出的 min week 实际 上等于 PRF 原始数据的第二小 week。 这意味着每周三更新 PRF 并刷新 Excel 后： - 10_prf_long 的 min week 自动 +1（例如 22 → 23） - 12_open_po 的 MinPRFWeek 跟着 

变 - 原本聚合在旧首周（如 22）的 Open PO 自动重新聚合到新首周（如 23） 无需手 动维护。PQ 依赖链保证 10_prf_long 先于 12_open_po 刷新。 

## 数据来源 

与 FDD 模块共用同一张 PO Confirmation 数据表（SSD_Scode_Output_Full），但筛选 条件不同： 

|与FDD模块共用同一张PO C<br>条件不同：|onfrmation数据表（SSD_Sc|ode_Output_Full），但筛选|
|---|---|---|
|条件|值|原因|
|Plant<br>|IN ('TW02', 'CN04')|scode层面的工厂|
|Confrmation Category|= 'LA'|scode层面只有 LA状态|
|Filename_date|MAX per PO|每个 PO只保留最新快照|
|Item delivery date (PO)|>= 2026-01-01|只看 2026年之后交期|
|Open PO Qty|> 0|排除已全部发运完成的 PO|



## 与 **FDD** 模块的区别 

|与**FDD**模块的区|别||||
|---|---|---|---|---|
|模块|层级|**Plant**筛选|**Category **筛选|用途|
|FDD|pcode层|CN02, US07|AB|评估ODM供<br>给承诺vs模型<br>需求|
|Open PO|scode层|TW02, CN04|LA|纳入在途供<br>给，优化库存<br>覆盖精度|



## 8.4 关键设计决策 

1. Material Number 直接就是 scode（因为 TW02/CN04 是 scode 工厂），不需要通过 MM_MAP 做 pcode → scode 映射 

2. 时间维度按 Item delivery date (PO) 转成 YYYYWW 格式的 week，与 scode roll 对齐 

3. 与 BOH 不会重复：Quantity Reduced (MRP) 已扣掉已发运量，已到仓部分已反映在 BOH 中 

4. 与 AGI 无关：AGI 仅在 pcode 层用于回推 BOH，scode 层不涉及 

5. 按 site 严格隔离：PTI 的 Open PO 只加到 PTI，Pega 的 Open PO 只加到 Pega 

## 8.5 修改后的 scode 层覆盖公式 

## 修改前： 

```
end_inventory[w] = BOH[w] - demand[w]
```

## 修改后： 

```
available[w]     = BOH[w] + open_po[w]
end_inventory[w] = MAX(0, available[w] - demand[w])
net_need[w]      = MAX(0, demand[w] - available[w])
BOH[w+1]         = end_inventory[w]
```

注意：09_scode_roll 的 PQ 输出仅包含静态库存快照 

（pti/pega_scode_inventory_qty）， 真正的逐周滚动（end_inventory、net_need）由 Excel 公式完成。 下游 11_final_compare 在引用 BOH 时，取的是 Excel 公式计算后的 end_inventory 列（而非 PQ 输出的静态快照）， 并通过 week + 1 偏移将本周 EOH 转化 为下周 BOH，同时设置 MAX(0) 下限保护。 08_pcode_roll 同理：PQ 输出已包含完整的 pcode 层滚动覆盖结果 （us07_net_need、cn02_us_net_need、 cn02_nonus_net_need）， 原 Excel 公式列（end_us07_inventory_qty、 end_cn02_inventory_qty、 US07_net_need2、CN02_net_need）为历史遗留，已废弃可 删除。 

## 8.6 Open PO SQL 实现 

```
WITH LatestSnapshot AS (
    SELECT
        [Purchasing Document Number],
        MAX([Filename_date]) AS max_snapshot_date
    FROM [SSD_Scode_Output].[dbo].[SSD_Scode_Output_Full]
    GROUP BY [Purchasing Document Number]
)
SELECT
    t.[Purchasing Document Number],
    t.[Material Number]                         AS scode,
    t.[Plant],
    t.[Site],
    t.[Item delivery date (PO)]                 AS delivery_date,
    YEAR(t.[Item delivery date (PO)]) * 100
        + DATEPART(ISO_WEEK, t.[Item delivery date (PO)]) AS week,
    MAX(t.[Quantity (PO)])                      AS po_qty,
    SUM(t.[Quantity Reduced (MRP)])             AS total_shipped_qty,
    MAX(t.[Quantity (PO)])
        - SUM(t.[Quantity Reduced (MRP)])       AS open_po_qty
```

```
FROM [SSD_Scode_Output].[dbo].[SSD_Scode_Output_Full] t
```

```
INNER JOIN LatestSnapshot s
    ON  t.[Purchasing Document Number] = s.[Purchasing Document Number]
    AND t.[Filename_date] = s.max_snapshot_date
WHERE t.[Plant] IN ('TW02', 'CN04')
  AND t.[Confirmation Category] = 'LA'
  AND t.[Item delivery date (PO)] >= '2026-01-01'
```

```
GROUP BY
```

```
    t.[Purchasing Document Number],
    t.[Material Number],
```

```
    t.[Plant],
    t.[Site],
    t.[Item delivery date (PO)],
    YEAR(t.[Item delivery date (PO)]) * 100
        + DATEPART(ISO_WEEK, t.[Item delivery date (PO)])
```

```
HAVING MAX(t.[Quantity (PO)]) - SUM(t.[Quantity Reduced (MRP)]) > 0
```

```
ORDER BY t.[Material Number], t.[Item delivery date (PO)]
```

## 8.7 PQ 集成路径 

`SQL` 输出（ `scode` 粒度） 

`→ PQ` 查询 `12_open_po` ：按 `scode + site + week` 汇总， `pivot` 成 `PTI / Pega` 两列 

- → 早期 `PO` 聚合： `week < MinPRFWeek` 的行归入 `MinPRFWeek` ，按 `scode + week` 重新 `SUM` 

- `→ LEFT JOIN` 到 `09_scode_roll` 

- → 修改 `roll` 公式： `available = BOH + open_po` 

## 8.8 Open PO 对主链的影响 

- 不改变：上游所有逻辑（Allocation 路由、AGI、pcode 层覆盖、pcode → scode 映 射） 

- 不改变：下游对比逻辑（gap_vs_prf、gap_vs_openFDD） 

- 仅修改：09_scode_roll 中每周可支配库存的计算方式（BOH → BOH + Open PO） 

## 8.9 Open PO 已知边界 

- Open PO 基于 Item delivery date (PO) 分周，实际到货时间可能偏移 

- 当前仅覆盖 TW02/CN04 工厂的 LA 记录，其他工厂不在范围内 

- 当前输出约 35 行有效数据，大部分集中在最近 1–2 周 

- 早期 Open PO（week < PRF 起始周）已自动聚合到首周，不会丢失； 但如果 PRF 起 始周发生变化（如周三更新），聚合目标周会自动跟着变 

## 8.10 scode 层核心输出 

- pti_net_need_qty 

- pega_net_need_qty 

## 9. PRF 处理方式与 Compare 逻辑 

PRF 是模型的第一层 benchmark。当前约定为：PRF sheet 名固定为 PRF，每周手动将 最新 PRF 粘贴或移动到该 sheet 中。 

PRF 的有效粒度为 odm_desc + scode + week，其中 mmnumber / mm_number 作为 scode 使用。在 Power Query 中，PRF 表会被整理成长表结构 prf_long。 

模型最终会在 week + scode + odm_desc 粒度与 prf_long 进行 merge，并计算： 

gap_vs_prf = prf_qty - predicted_qty 

正值表示工厂计划充足，负值表示工厂计划不足。方向与 gap_vs_openFDD 统一：正 = 够，负 = 不够。 

## 10. FDD 模块逻辑说明 

## 10.1 模块定位与目标 

FDD 模块是在现有模型完成 gap_vs_prf 对比之后新增的第二层对比。其目标是从 ODM 供给侧出发，评估 ODM 实际承诺的交付量能否满足模型推算出的净需求。 

## 两层对比结构： 

|两层对比结构：|||
|---|---|---|
|层级|公式|回答的问题|
|第一层|gap_vs_prf = prf_qty -<br>predicted_qty|模型推算vs工厂计划|
|第二层|gap_vs_openFDD = BOH +<br>prf_qty + open_po -<br>open_fdd|该周总供给能否覆盖FDD<br>承诺的出货量|



两个 gap 方向统一： 正 **=** 供给充足，负 **=** 供给不足 。 

## 10.2 FDD 业务背景 

从需求规划到最终交付存在一条完整的生命周期链路。FDD（Factory Delivery Date）代 表 ODM 侧的供给承诺： 

|阶段|**SAP**标识|状态|含义|
|---|---|---|---|
|BA|BA|非FDD|内部规划+试探<br>ODM产能，无正式<br>承诺|
|BE（刚下单）|BE, AB=0|Open FDD|已正式下PO，但<br>ODM尚未确认|
|BE（已确认）|BE, AB>0|Committed FDD|ODM正式承诺了供<br>给数量|
|LA|LA (ShpgNt)|执行中supply|已进入生产/发运，<br>不再属于FDD讨论<br>范畴|



## 10.3 Open FDD 定义 

Open FDD 统一包含 AB = 0（未确认）和 AB > 0（已确认）两种状态，不做进一步拆分。 即 FDD supply 中既包含确定性较高的 committed 量，也包含尚未回复的 open 量。 

## 10.4 数据来源与获取逻辑 

数据来源：PO Confirmation 数据库（AB report），每日录入快照。 

筛选条件： 

- 交货日期过滤：只取 Item delivery date (Actual) ≥ 当前周的数据 

- 去重：同一 Purchasing Document Number 只保留最新 Filename_date 的快照 

- 过滤 LA：Quantity (Actual) - Quantity Reduced (MRP) ≠ 0 的记录即为非 LA 状态 

## 10.5 核心字段说明 

|10.5核心字段说明|||
|---|---|---|
|字段名|说明|备注|
|Purchasing Document<br>Number|PO编号|去重主键之一|
|Material Number|pcode（产品编码）|FDD原始粒度|
|Plant|工厂代码|CN02 → Pega；US07 → PTI|
|Quantity (PO)|PO下单数量|我们要求的量|



|Quantity (Actual)|AB确认数量|ODM承诺的供给量|
|---|---|---|
|Quantity Reduced (MRP)|已发运/已完成数量|用于判断是否为 LA|
|Item delivery date (Actual)|ODM承诺交货日期|用于推导 week|
|Filename_date|数据快照日期|用于去重取最新版本|



## 10.6 层级流转 

FDD 原始数据在 pcode 层获取（Material Number），随后通过 pcode → scode 映射表聚 合到 scode 层。由于一个 pcode 对应唯一 scode，聚合方向为 sum。 

odm_desc 由 Plant 字段直接推导：CN02 → Pega，US07 → PTI。 

最终 FDD supply 的粒度为 week + scode + odm_desc，与现有模型输出粒度完全一致。 

## 10.7 对比逻辑 

gap_vs_openFDD 的计算方式已从"predicted vs FDD"改为基于 scode 层每周供给的独立 评估： gap_vs_openFDD = BOH + prf_qty + open_po − open_fdd 

## 其中： 

- BOH：该 scode 在该周的期初库存（直接取自 09_scode_roll，已经过 pcode 层需求扣 减后的滚动结果） 

- prf_qty：该周工厂产量（来自 10_prf_long） 

- open_po：该周在途采购订单（来自 12_open_po → 09_scode_roll） 

- open_fdd：FDD 承诺出货量（来自 FDD_OpenQty，week 已提前一周偏移） 

FDD 时间偏移：FDD 原始数据的 week 整体 -1 后再与主表 join。原因是 scode 需要提 前一周备好货， 才能满足 pcode 层面下周的出货，与 09 中 scode gross need 的 week -1 偏移逻辑一致。 

## Gap 含义： 

|Gap含义：|||
|---|---|---|
|**gap **值|含义|建议动作|
|> 0|该周总供给> FDD承诺 →<br>供给充足，PRF合理|正常跟踪|
|< 0|该周总供给< FDD承诺 →<br>供给不足，存在缺口|推动补量或调整计划|
|= 0|供需平衡|正常跟踪|



||""（空）|该周无FDD承诺<br>（open_fdd = 0），不适用|无需关注||
|---|---|---|---|---|



注意：当 open_fdd = 0 时，gap_vs_openFDD 输出为空字符串 ""，而非 null 或 0， 表 示该周没有 FDD 承诺，比较无意义。 

## 10.8 FDD 时间特性与决策参考 

FDD 一般安排在三周内，而模型 predicted_qty 在前三周往往为 0（因为库存尚未耗尽）。 这导致逐周对比 gap_vs_openFDD 在短期内信息量有限。 

## 时间特性总结： 

|时间特性总结：|||
|---|---|---|
|时间窗口|主要参考依据|原因|
|短期（≤3周）|FDD|FDD是实际已下PO的承<br>诺，确定性最高|
|中长期（> 3周）|Allocation-driven<br>predicted_qty|FDD尚未形成，Allocation<br>是唯一能反映demand<br>pressure的来源|



## **FDD** 独立评估路径（设计方向）： 

FDD 独立评估路径（已落地）： 当前版本已实现独立于 predicted_qty 的 FDD 评估方式。 gap_vs_openFDD 不再使用 predicted_qty - FDD 的对比模式，而是直接以每周的 BOH + PRF + Open PO 作为总供给， 与 FDD 承诺量进行比较。该方式每周独立产出一个值：> 0 表示供给可支撑 FDD 承诺； < 0 表示该周供给不足。此路径完全独立于 predicted_qty，适合按周决策。 

## 10.9 与现有模型的关系 

## FDD 模块不改变现有主链逻辑。核心要点： 

- FDD supply 代表 ODM 未来承诺交付的量，与仓库中的现有库存是两回事 

- predicted need 已经扣除了所有库存（pcode + scode 两层），是净需求 

- FDD 不需要再额外扣减库存，否则会导致库存被重复扣减 

类比：库存 = 冰箱里已有的货；FDD = 供应商承诺明天送来的货。predicted need 是冰箱 卖完后还差的量，FDD 用来评估这个缺口能不能被填上。 

## 10.10 已知误差与边界 

|10.10已知误差与边界|||
|---|---|---|
|项目|说明|影响方向|
|LA在途不纳入|已发运但未入库的货物被过<br>滤掉，一般三天内到货|gap略偏悲观|
|AB=0与AB>0混合统计|未区分已确认和未确认的<br>FDD，可能高估供给确定性|gap偏乐观|
|ODM交期可能延迟|承诺的交货日期不一定准时|某一周 gap 偏乐观|
|PO未确认部分不可见|PO下了1000但只<br>commit 600，剩余400不<br>可见|gap偏悲观|



## 11. 最终输出层（11_final_compare） 

最终输出在 week + scode + odm_desc 粒度上合并所有对比结果： 

|列名|含义|来源|
|---|---|---|
|predicted_qty|模型推算的净需求|scode层库存覆盖后穿透量|
|prf_qty|工厂排产计划|PRF表|
|gap_vs_prf|模型 vs工厂计划|predicted_qty - prf_qty|
|FDD_OpenQty|ODM供给承诺|FDD_OpenQty 表|
|gap_vs_openFDD|模型vs ODM承诺|predicted_qty -<br>FDD_OpenQty（FDD无记<br>录时为 null）|
|BOH|该周 scode期初库存|09_scode_roll（已滚动）|
|open_po|该周在途采购订单|12_open_po →<br>09_scode_roll|
|open_fdd<br>|FDD承诺出货量（week已<br>-1偏移）|FDD_OpenQty（偏移后）|
|fnal_gap|最终缺口建议值|综合gap_vs_prf与<br>gap_vs_openFDD：两者都<br>负取绝对值更大的；仅<br>FDD负以FDD为准；仅<br>PRF负以 PRF为准；都正|



则不显示；无 FDD 时回退 到 PRF 

两个 gap 方向统一：正 = 够，负 = 不够。 

关键实现细节： 

- gap_vs_prf 公式方向为 prf_qty - predicted_qty，正值表示工厂计划充足 

- gap_vs_openFDD 采用每周独立的供给评估：BOH + PRF + Open PO − FDD， 不再依赖 predicted_qty 与 FDD 的直接相减 

- FDD 数据在 join 前整体 week - 1，对齐 scode 提前一周备货的 lead time - open_fdd = 0 时 gap_vs_openFDD 输出空字符串 ""，区分"无 FDD 承诺"和"FDD 数量确实为 0" 

- Unpivot 前需先对 pti_net_need_qty / pega_net_need_qty 做 null → 0 替换，防止 unpivot 静默丢弃行 

- FDD 独有的 week + scode + odm_desc 组合需补入 base（predicted_qty = 0），确保 FDD 数据不因 base 缺行而丢失 

- 输出表过滤掉 PRF 起始周之前的行（week < MinPRFWeek），避免无 PRF 数据的周混 入结果 

- BOH 取自 09_scode_roll 的 end_pti_inventory_qty / end_pega_inventory_qty（Excel 公 式滚动后的期末库存）， 并将 week + 1 偏移，使本周 EOH 对齐为下周 BOH。由于 11 的最小周一定大于 09 的最小周， 不存在首周缺数据的问题。BOH 设有下限保护： MAX(boh, 0)，确保不出现负库存。 

## 12. 当前版本已废弃的旧逻辑 

## 为避免后续继续混用旧路径，以下逻辑已明确废弃： 

- AGI 扣 demand（agi_qty_applied、open_total_allocation_qty、 

open_us_allocation_qty、open_non_us_allocation_qty） 

- 以 weighted_us_rate 为核心继续往后推的旧路径 

- pcode 层"non-US demand 先吃 CN02，不够再吃 US07 剩余"的单向补位规则 

- 旧版 us_allocation_qty / non_us_allocation_qty 两列拆分方式（不区分 plant） 

- 旧版按 plant 分别拆分的三列（CN02_us_allocation / CN02_non_us_allocation / US07_us_allocation）及独立的 PTI_CONSOLIDATED override 判断分支 

- 旧版全局 us_rate split 与 US07 plant 原始量取 MAX 的分配逻辑 （已替换为 V4 routing：US07 优先覆盖 + CN02 承接溢出） 

- 08_pcode_roll 的 Excel 公式列（N-Q 列：end_us07_inventory_qty、 end_cn02_inventory_qty、 US07_net_need2、CN02_net_need）——PQ 已在内部完 成 pcode 层滚动覆盖，这些列功能重复且已损坏（#REF!） 

- 

## 13. 当前版本的关键假设与边界 

当前 demo 聚焦于"需求拆分 + 库存覆盖 + PRF 对比 + FDD 对比"这条主链，不纳入 backlog / open order、capacity 约束、更多 plant 扩展，以及完整的 MD04 / AB report 业 务链条。 

## 核心边界条件： 

- AGI 仅作为周初 BOH 回推依据，不再作为 demand 扣减项 

- pcode 层 US07 / CN02 完全隔离，不允许任何跨 plant 补位 

- scode 层 PTI / PEGA 完全隔离 

- PTI_CONSOLIDATED = "100%" 的 scode 全部路由到 PTI 

- FDD 前三周与 predicted_qty 存在时间错位，逐周 gap 在短期内信息量有限 

- Open PO 基于 Item delivery date (PO) 分周，实际到货时间可能偏移 

- Open PO 当前仅覆盖 TW02/CN04 工厂的 LA 记录，其他工厂不在范围内 

- Open PO 当前输出约 35 行有效数据，大部分集中在最近 1–2 周 

## 14. 后续可优化方向 

- ❌（已完成）FDD 独立评估路径：当前版本已实现 BOH + PRF + Open PO − FDD 的每 周独立评估，不再依赖 predicted_qty 

- 区分 Committed / Open FDD：标记 AB > 0（committed）和 AB = 0（open），评估 供给确定性 

- Effective supply 指标：effective_supply = min(prf_qty, FDD_OpenQty)，识别 binding constraint 

- Bottleneck flag：标记当前瓶颈在 PRF 侧还是 FDD 侧，辅助决策 

- Open PO 实际到货偏差追踪：基于历史 Item delivery date (PO) 与实际入库日期对比， 评估 Open PO 预测精度 

- 交期可靠性评估：基于历史数据分析 ODM 交期偏差，为 gap 增加置信区间 

## 15. 一句话总结 

当前项目以 Allocation 作为 gross demand 起点，在 pcode + demand_group 按 us_rate 拆分 US / non-US 需求后， 通过 V4 routing 在 scode 层决定 US07 优先覆盖、CN02 承 接溢出，并引入 lead time 使 US07 相对 CN02 前移一周； AGI 用于将当前库存回推为 本周开始时的 BOH。模型在 pcode 层按 US07 / CN02 完全隔离规则做第一层库存覆盖， 在 scode 层将 BOH 与 Open PO（在途供给）合并后按 PTI / PEGA 完全隔离规则做第 二层库存覆盖。 最终按 week + scode + odm_desc 输出两层对比： gap_vs_prf = prf_qty − predicted_qty（工厂计划是否覆盖模型需求）； gap_vs_openFDD = BOH + prf_qty + open_po − open_fdd（BOH 取自 09 滚动后的 end_inventory 并 week+1 偏移， FDD 已 提前一周偏移，BOH 下限为 0）。新增 final_gap 列，综合两个 gap 的结果：任一为负 则取最大缺口值作为调整建议，两者都正则不显示。 

## 附录：简版摘要（适用于 Excel 首页 / README） 

本项目以 Allocation 为 gross demand 起点，在 pcode + demand_group 按 allocation V4 routing 与 US07 plant 原始量取 MAX 拆分 US / non-US 需求；AGI 用于将当前库存回推为 本周开始时的 BOH。模型先在 pcode 层按 US07 / CN02 完全隔离规则进行第一层库存 覆盖，再在 scode 层将 BOH 与 Open PO（在途供给）合并后按 PTI / PEGA 完全隔离规 则进行第二层库存覆盖，最终按 week + scode + odm_desc 分别与 PRF 和 FDD 对比，输 出 predicted_qty、prf_qty、gap_vs_prf（= prf_qty − predicted_qty）、 boh、open_po、 open_fdd 和 gap_vs_openFDD（= BOH + prf_qty + open_po − open_fdd）。 两个 gap 方 向统一：正 = 够，负 = 不够。 

