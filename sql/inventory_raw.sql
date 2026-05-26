-- ============================================================
-- SDA Framework | inventory_raw
-- 统一库存查询：pcode inventory + scode inventory
-- 
-- 数据源: vFact_SapDirect_Mchb + vDim_SapDirect_Mara
-- 输出层: inventory_raw（供 Power Query 06_pcode_inventory 
--         和 09_scode_roll 使用）
-- ============================================================

/*
目标：
1. 用同一张库存源表，统一抽出 pcode inventory + scode inventory
2. 用 inventory_level 区分两条分支
3. 每个 plant 取最新一版 snapshot
4. pcode 分支保留 COO / is_us_sellable
5. scode 分支先不使用 COO（置空），避免后续误用
*/

WITH latest_ts AS (
    SELECT
        m.[plant],
        MAX(m.[asof_datetime]) AS [latest_asof_datetime]
    FROM [gops_data_staging_ent].[dbo].[vFact_SapDirect_Mchb] m
    INNER JOIN [gops_data_staging_ent].[dbo].[vDim_SapDirect_Mara] a
        ON m.[mtrl_trim_id] = a.[mtrl_trim_id]
    WHERE
        m.[plant] IN ('CN02', 'US07', 'TW02', 'CN04')
        AND a.[ext_material_group] IN ('PFDD', 'SFDD', 'NFDD')
    GROUP BY
        m.[plant]
),

base_inventory AS (
    SELECT
        m.[asof_datetime],
        LTRIM(RTRIM(m.[material])) AS [material],
        m.[plant],
        UPPER(LTRIM(RTRIM(m.[batch]))) AS [batch],
        m.[storage_location],

        COALESCE(m.[unrestricted], 0)       AS [unrestricted],
        COALESCE(m.[blocked], 0)            AS [blocked],
        COALESCE(m.[quality_inspection], 0) AS [quality_inspection],
        COALESCE(m.[stock_in_transfer], 0)  AS [stock_in_transfer],

        UPPER(LTRIM(RTRIM(a.[ext_material_group]))) AS [ext_material_group]
    FROM [gops_data_staging_ent].[dbo].[vFact_SapDirect_Mchb] m
    INNER JOIN [gops_data_staging_ent].[dbo].[vDim_SapDirect_Mara] a
        ON m.[mtrl_trim_id] = a.[mtrl_trim_id]
    INNER JOIN latest_ts t
        ON m.[plant] = t.[plant]
       AND m.[asof_datetime] = t.[latest_asof_datetime]
    WHERE
        m.[plant] IN ('CN02', 'US07', 'TW02', 'CN04')
        AND a.[ext_material_group] IN ('PFDD', 'SFDD', 'NFDD')
        AND (
            COALESCE(m.[unrestricted], 0)
          + COALESCE(m.[blocked], 0)
          + COALESCE(m.[stock_in_transfer], 0)
        ) > 0
)

/* ===== 统一输出：pcode 分支 + scode 分支 ===== */
SELECT
    b.[asof_datetime],
    'PCODE' AS [inventory_level],
    b.[material] AS [inventory_code],   -- 在 pcode 分支中，material = pcode
    b.[material],
    b.[plant],
    b.[batch],
    b.[storage_location],
    b.[unrestricted],
    b.[blocked],
    b.[quality_inspection],
    b.[stock_in_transfer],
    b.[ext_material_group],

    /* pcode 分支：按 batch 推 COO */
    CASE
        WHEN b.[batch] IS NOT NULL
         AND LEN(b.[batch]) > 8
            THEN UPPER(SUBSTRING(b.[batch], 1, LEN(b.[batch]) - 8))
        ELSE NULL
    END AS [COO],

    CASE
        WHEN b.[batch] IS NOT NULL
         AND LEN(b.[batch]) > 8
         AND UPPER(SUBSTRING(b.[batch], 1, LEN(b.[batch]) - 8)) = 'TW'
            THEN 1
        ELSE 0
    END AS [is_us_sellable]

FROM base_inventory b
WHERE
    b.[plant] IN ('CN02', 'US07')
    AND b.[ext_material_group] IN ('PFDD', 'SFDD', 'NFDD')

UNION ALL

SELECT
    b.[asof_datetime],
    'SCODE' AS [inventory_level],
    b.[material] AS [inventory_code],   -- 在 scode 分支中，material = scode
    b.[material],
    b.[plant],
    b.[batch],
    b.[storage_location],
    b.[unrestricted],
    b.[blocked],
    b.[quality_inspection],
    b.[stock_in_transfer],
    b.[ext_material_group],

    /* scode 分支：当前业务先不使用 COO */
    NULL AS [COO],
    NULL AS [is_us_sellable]

FROM base_inventory b
WHERE
    b.[plant] IN ('TW02', 'CN04')
    AND b.[ext_material_group] = 'SFDD'

ORDER BY
    [inventory_level],
    [plant],
    [inventory_code],
    [batch];
