\o instance_db_info.txt

\qecho "DB INFO : "
SELECT Inet_server_addr() AS "Server IP", 
       Version()          AS "Postgres Version", 
       setting            AS "Port Number", 
       current_timestamp :: timestamp
FROM   pg_settings 
WHERE  name = 'port'; 

\qecho "Parameter INFO : "
SELECT name, unit, setting FROM pg_settings WHERE name ='port'                 
UNION ALL
SELECT name, unit, setting FROM pg_settings WHERE name ='shared_buffers'        -- shared_buffers determines how much memory is dedicated for caching data
UNION ALL
SELECT name, unit, setting FROM pg_settings WHERE name ='work_mem'              -- work memory required for each incoming connection
UNION ALL
SELECT name, unit, setting FROM pg_settings WHERE name ='maintenance_work_mem'  -- work memory of maintenace type queries "VACUUM, CREATE INDEX etc."
UNION ALL
SELECT name, unit, setting FROM pg_settings WHERE name ='wal_buffers'           -- Sets the number of disk-page buffers in shared memory for WAL
UNION ALL          
SELECT name, unit, setting FROM pg_settings WHERE name ='effective_cache_size'  -- used by postgres query planner
UNION ALL
SELECT name, unit, setting FROM pg_settings WHERE name ='TimeZone'              -- server time zone;
 
-- Option 2: SHOW ALL
-- The SHOW ALL command displays all current configuration setting of in three columns
SHOW all;
 
-- Option 3: PG_FILE_SETTINGS
-- To read what is stored in the postgresql.conf file itself, use the view pg_file_settings.
TABLE pg_file_settings ;

