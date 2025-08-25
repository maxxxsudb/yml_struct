-- Копируй список ролей из экспорта сюда между кавычек
WITH exported_roles AS (
    SELECT REGEXP_SUBSTR(grant_cmd, '"([^"]+)"', 1, 1, '', 1) AS role_name
    FROM (
        -- ВСТАВЬ СЮДА ВСЕ СТРОКИ GRANT "..." TO "REVOLUTE"; ИЗ ЭКСПОРТА
        SELECT 'GRANT "MODELING" TO "REVOLUTE";' AS grant_cmd FROM DUMMY
        UNION ALL SELECT 'GRANT "MONITORING" TO "REVOLUTE";' FROM DUMMY  
        -- ДОБАВЬ ВСЕ ОСТАЛЬНЫЕ СТРОКИ GRANT
    )
    WHERE grant_cmd LIKE 'GRANT "%' 
)
SELECT 'MISSING ROLE: ' || er.role_name AS missing_items
FROM exported_roles er
LEFT JOIN ROLES r ON er.role_name = r.role_name  
WHERE r.role_name IS NULL
UNION ALL
SELECT 'USER EXISTS: REVOLUTE' FROM USERS WHERE USER_NAME = 'REVOLUTE';
