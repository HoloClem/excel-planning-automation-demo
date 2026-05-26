-- ============================================================
-- SDA Framework | 01_alloc_raw
-- Allocation 原始数据查询（gross demand 起点）
-- 
-- 服务器: goapps-sql.corp.nandps.com, 1433
-- 数据库: gops_data_staging_ent
-- 数据源: vFact_AllocationCmad + MM_MAP (scode → pcode 映射)
-- 输出层: 01_alloc_raw（供 Power Query 03_alloc_pcode_level 使用）
-- ============================================================

WITH MM_MAP AS (
    SELECT DISTINCT
        T1.mtrl_trim_id AS Scode,
        C.bom_component AS pcode
    FROM 
        (SELECT [mtrl_trim_id]
         FROM [gops_data_staging_ent].[dbo].[tDim_SapDirect_Characteristics]
         WHERE [characteristic_name] = 'MARKET_CODE_NAME') AS T1
    LEFT JOIN [gops_data_staging_ent].[dbo].[vDim_SapDirect_Mast] AS A
        ON T1.mtrl_trim_id = A.mtrl_trim_id
    LEFT JOIN [gops_data_staging_ent].[dbo].[vDim_SapDirect_STKO] AS B
        ON A.client = B.client
       AND A.bill_of_material = B.bill_of_material
    LEFT JOIN [gops_data_staging_ent].[dbo].[vDim_SapDirect_STPO] AS C
        ON C.client = B.client
       AND C.bill_of_material = B.bill_of_material
    LEFT JOIN [gops_data_staging_ent].[dbo].[vDim_SapDirect_Mara] AS D
        ON T1.mtrl_trim_id = D.mtrl_trim_id
    WHERE D.ext_material_group IN ('PFDD','NFDD')
      AND D.[x-plant_matstatus] < 60
      AND C.valid_from_date = (
            SELECT MAX(C2.valid_from_date)
            FROM [gops_data_staging_ent].[dbo].[vDim_SapDirect_STPO] AS C2
            WHERE C.bill_of_material = C2.bill_of_material
      )
)
SELECT
    M.pcode,
    A.demand_group,
    A.plant,
    A.week,
    A.allocation_qty,
    A.item_name AS Scode
FROM [gops_data_staging_ent].[edw_repl].[vFact_AllocationCmad] AS A
LEFT JOIN MM_MAP AS M
    ON A.item_name = M.Scode;
