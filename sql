SELECT 
    pid, 
    usename, 
    application_name,
    age(now(), query_start) AS duration,
    query 
FROM 
    pg_stat_activity 
WHERE 
    state = 'active' 
    AND query_start >= now() - INTERVAL '1 minute'
    AND pid <> pg_backend_pid(); -- исключаем этот самый запрос
