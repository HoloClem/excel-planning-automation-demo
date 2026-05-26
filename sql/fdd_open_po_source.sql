-- ============================================================
-- SDA Framework | FDD & Open PO 共用数据源
-- PO Confirmation 最新快照查询
-- 
-- 数据源: SSD_Scode_Output_Full (AB Report，每日录入快照)
-- 去重逻辑: 通过 Ingest_Filename 中的日期取最新一天的完整快照
-- 
-- 下游用途:
--   ├── FDD 模块    → PQ 内按 Plant IN ('CN02','US07'), Category='AB' 筛选
--   └── Open PO 模块 → PQ 内按 Plant IN ('TW02','CN04'), Category='LA' 筛选
-- 
-- 详见项目文档 §8.3 (Open PO) 和 §10.4 (FDD) 
-- ============================================================

SELECT *
FROM [SSD_Scode_Output].[dbo].[SSD_Scode_Output_Full]
WHERE CAST(SUBSTRING(Ingest_Filename, LEN(Ingest_Filename) - 11, 8) AS DATE) =
(
    SELECT MAX(CAST(SUBSTRING(Ingest_Filename, LEN(Ingest_Filename) - 11, 8) AS DATE))
    FROM [SSD_Scode_Output].[dbo].[SSD_Scode_Output_Full]
)
