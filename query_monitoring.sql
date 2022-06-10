1. Get server IP address, version and port number
-- query server version (standard major.minor.patch format) 
SELECT Inet_server_addr() AS "Server IP", 
       Version()          AS "Postgres Version", 
       setting            AS "Port Number", 
       current_timestamp :: timestamp
FROM   pg_settings 
WHERE  name = 'port'; 

2. Get server version
SHOW server_version;
 
3. Get system info
-- Server up time 
SELECT Inet_server_addr() 
       AS
       Server_IP --server IP address 
       , 
       Inet_server_port() 
       AS Server_Port --server port 
       , 
       Current_database() 
       AS Current_Database --Current database 
       , 
       current_user
       AS Current_User --Current user 
       , 
       Pg_backend_pid() 
       AS ProcessID --Current user pid 
       , 
       Pg_postmaster_start_time() 
       AS Server_Start_Time --Last start time 
       , 
       current_timestamp :: TIMESTAMP - Pg_postmaster_start_time() :: TIMESTAMP
       AS
       Running_Since; 


4. Get details of postgres configuration parameter
-- Option 1: PG_SETTINGS
-- This gives you a lot of useful info about postgres instance
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


5. Get OS information
-- Get OS Version
SELECT version();
 
| OS     | Wiki References                                       |
| ------ | ----------------------------------------------------- |
| RedHat | wikipedia.org/wiki/Red_Hat_Enterprise_Linux           |
| Windows| wikipedia.org/wiki/List_of_Microsoft_Windows_versions |
| Mac OS | wikipedia.org/wiki/MacOS              |
| Ubuntu | wikipedia.org/wiki/Ubuntu_version_history         |
6. Get location of data directory (this is where postgres stores the database files)
SELECT NAME, 
       setting 
FROM   pg_settings 
WHERE  NAME = 'data_directory'; 
--OR 
SHOW data_directory;


7. List all databases along with creation date
SELECT datname AS database_name, 
       (Pg_stat_file('base/'
              ||oid 
              ||'/PG_VERSION')).modification as create_timestamp 
FROM   pg_database 
WHERE  datistemplate = false;

8. Get an overview of current server activity
SELECT
    pid
    , datname
    , usename
    , application_name
    , client_addr
    , to_char(backend_start, 'YYYY-MM-DD HH24:MI:SS TZ') AS backend_start
    , state
    , wait_event_type || ': ' || wait_event AS wait_event
    , pg_blocking_pids(pid) AS blocking_pids
    , query
    , to_char(state_change, 'YYYY-MM-DD HH24:MI:SS TZ') AS state_change
    , to_char(query_start, 'YYYY-MM-DD HH24:MI:SS TZ') AS query_start
    , backend_type
FROM
    pg_stat_activity
ORDER BY pid;


8. Get max_connections configuration
SELECT NAME, 
       setting, 
       short_desc 
FROM   pg_settings 
WHERE  NAME = 'max_connections';

9. Get total count of current user connections
SELECT Count(*) 
FROM   pg_stat_activity; 

10. Get active v/s inactive connections
SELECT state, 
       Count(pid) 
FROM   pg_stat_activity 
GROUP  BY state, 
          datname 
HAVING datname = '<your_database_name>'
ORDER  BY Count(pid) DESC; 
 
-- One row per server process, showing database OID, database name, process ID, user OID, user name, current query, query's waiting status, time at which the current query began execution
-- Time at which the process was started, and client's address and port number. The columns that report data on the current query are available unless the parameter stats_command_string has been turned off.
-- Furthermore, these columns are only visible if the user examining the view is a superuser or the same as the user owning the process being reported on
Database specific queries
**** Switch to a user database that you are interested in *****

11. Get database current size (pretty size)
SELECT Current_database(), 
       Pg_size_pretty(Pg_database_size(Current_database())); 

12. Get top 20 objects in database by size
SELECT nspname                                        AS schemaname, 
       cl.relname                                     AS objectname, 
       CASE relkind 
         WHEN 'r' THEN 'table'
         WHEN 'i' THEN 'index'
         WHEN 'S' THEN 'sequence'
         WHEN 'v' THEN 'view'
         WHEN 'm' THEN 'materialized view'
         ELSE 'other'
       end                                            AS type, 
       s.n_live_tup                                   AS total_rows, 
       Pg_size_pretty(Pg_total_relation_size(cl.oid)) AS size
FROM   pg_class cl 
       LEFT JOIN pg_namespace n 
              ON ( n.oid = cl.relnamespace ) 
       LEFT JOIN pg_stat_user_tables s 
              ON ( s.relid = cl.oid ) 
WHERE  nspname NOT IN ( 'pg_catalog', 'information_schema' ) 
       AND cl.relkind <> 'i'
       AND nspname !~ '^pg_toast'
ORDER  BY Pg_total_relation_size(cl.oid) DESC
LIMIT  20; 
13. Get size of all tables
SELECT *, 
       Pg_size_pretty(total_bytes) AS total, 
       Pg_size_pretty(index_bytes) AS INDEX, 
       Pg_size_pretty(toast_bytes) AS toast, 
       Pg_size_pretty(table_bytes) AS TABLE
FROM   (SELECT *, 
               total_bytes - index_bytes - COALESCE(toast_bytes, 0) AS
               table_bytes 
        FROM   (SELECT c.oid, 
                       nspname                               AS table_schema, 
                       relname                               AS TABLE_NAME, 
                       c.reltuples                           AS row_estimate, 
                       Pg_total_relation_size(c.oid)         AS total_bytes, 
                       Pg_indexes_size(c.oid)                AS index_bytes, 
                       Pg_total_relation_size(reltoastrelid) AS toast_bytes 
                FROM   pg_class c 
                       LEFT JOIN pg_namespace n 
                              ON n.oid = c.relnamespace 
                WHERE  relkind = 'r') a) a; 

14. Get table metadata
SELECT relname, 
       relpages, 
       reltuples, 
       relallvisible, 
       relkind, 
       relnatts, 
       relhassubclass, 
       reloptions, 
       Pg_table_size(oid) 
FROM   pg_class 
WHERE  relname = '<table_name_here>'; 

15. Get table structure (i.e. describe table)
SELECT column_name, 
       data_type, 
       character_maximum_length 
FROM   information_schema.columns 
WHERE  table_name = '<table_name_here>'; 
                           
-- Does the table have anything unusual about it?
-- a. contains large objects
-- b. has a large proportion of NULLs in several columns
-- c. receives a large number of UPDATEs or DELETEs regularly
-- d. is growing rapidly
-- e. has many indexes on it
-- f. uses triggers that may be executing database functions, or is calling functions directly

----------LOCKING--------------------
16. Get Lock connection count
SELECT Count(DISTINCT pid) AS count
FROM   pg_locks 
WHERE  NOT granted; 

17. Get locks_relation_count
SELECT   relation::regclass  AS relname , 
         count(DISTINCT pid) AS count
FROM     pg_locks 
WHERE    NOT granted 
GROUP BY 1;

18. Get locks_statement_duration
SELECT a.query                                     AS blocking_statement, 
       Extract('epoch' FROM Now() - a.query_start) AS blocking_duration 
FROM   pg_locks bl 
       JOIN pg_stat_activity a 
         ON a.pid = bl.pid 
WHERE  NOT bl.granted; 

---------------------INDEXING--------------------------
19. Get missing indexes
SELECT
    relname AS TableName
    ,seq_scan-idx_scan AS TotalSeqScan
    ,CASE WHEN seq_scan-idx_scan > 0 
        THEN 'Missing Index Found'
        ELSE 'Missing Index Not Found'
    END AS MissingIndex
    ,pg_size_pretty(pg_relation_size(relname::regclass)) AS TableSize
    ,idx_scan AS TotalIndexScan
FROM pg_stat_all_tables
WHERE schemaname='public'
    AND pg_relation_size(relname::regclass)>100000 
        ORDER BY 2 DESC;

20. Get Unused Indexes
SELECT indexrelid::regclass AS INDEX , 
       relid::regclass      AS TABLE , 
       'DROP INDEX '
              || indexrelid::regclass 
              || ';' AS drop_statement 
FROM   pg_stat_user_indexes 
JOIN   pg_index 
using  (indexrelid) 
WHERE  idx_scan = 0 
AND    indisunique IS false;

21. Get index usage stats
SELECT t.tablename                                                         AS
       "relation", 
       indexname, 
       c.reltuples                                                         AS
       num_rows, 
       Pg_size_pretty(Pg_relation_size(Quote_ident(t.tablename) :: text))  AS
       table_size, 
       Pg_size_pretty(Pg_relation_size(Quote_ident(indexrelname) :: text)) AS
       index_size, 
       idx_scan                                                            AS
       number_of_scans, 
       idx_tup_read                                                        AS
       tuples_read, 
       idx_tup_fetch                                                       AS
       tuples_fetched 
FROM   pg_tables t 
       left outer join pg_class c 
                    ON t.tablename = c.relname 
       left outer join (SELECT c.relname   AS ctablename, 
                               ipg.relname AS indexname, 
                               x.indnatts  AS number_of_columns, 
                               idx_scan, 
                               idx_tup_read, 
                               idx_tup_fetch, 
                               indexrelname, 
                               indisunique 
                        FROM   pg_index x 
                               join pg_class c 
                                 ON c.oid = x.indrelid 
                               join pg_class ipg 
                                 ON ipg.oid = x.indexrelid 
                               join pg_stat_all_indexes psai 
                                 ON x.indexrelid = psai.indexrelid) AS foo 
                    ON t.tablename = foo.ctablename 
WHERE  t.schemaname = 'public'
ORDER  BY 1, 2;

------------------------QUERY PERFORMANCE-------------------------------------
22. Get top 10 costly queries
SELECT   r.rolname, 
         Round((100 * total_time / Sum(total_time::numeric) OVER ())::numeric, 2) AS percentage_cpu ,
         Round(total_time::numeric, 2)                                            AS total_time, 
         calls, 
         Round(mean_time::numeric, 2) AS mean, 
         Substring(query, 1, 800)     AS short_query 
FROM     pg_stat_statements 
JOIN     pg_roles r 
ON       r.oid = userid 
ORDER BY total_time DESC limit 5;

---------------------------CACHING--------------------------------
23. Get TOP cached tables & indexes
-- Measure cache hit ratio for tables
SELECT relname AS "relation", 
       heap_blks_read AS heap_read, 
       heap_blks_hit AS heap_hit, 
       COALESCE((( heap_blks_hit * 100 ) / NULLIF(( heap_blks_hit + heap_blks_read ), 0)),0) AS ratio 
FROM   pg_statio_user_tables
    ORDER BY ratio DESC;
 
-- Measure cache hit ratio for indexes
SELECT relname AS "relation",
    idx_blks_read AS index_read, 
    idx_blks_hit AS index_hit,
    COALESCE((( idx_blks_hit * 100 ) / NULLIF(( idx_blks_hit + idx_blks_read ), 0)),0) AS ratio
FROM pg_statio_user_indexes
    ORDER BY ratio DESC;


----------------------AUTOVACUUM & Data bloat--------------------------------
24. Last Autovaccum, live & dead tuples
SELECT relname AS "relation", 
       Extract (epoch FROM CURRENT_TIMESTAMP - last_autovacuum) AS since_last_av, 
       autovacuum_count AS av_count, 
       n_tup_ins, 
       n_tup_upd, 
       n_tup_del, 
       n_live_tup, 
       n_dead_tup 
FROM   pg_stat_all_tables 
WHERE  schemaname = 'public'
ORDER  BY relname; 

---------------------------------PARTITIONING------------------------------------
25. List all table partitions (as parent/child relationship)
SELECT nmsp_parent.nspname AS parent_schema, 
       parent.relname      AS parent, 
       child.relname       AS child, 
       CASE child.relkind 
         WHEN 'r' THEN 'table'
         WHEN 'i' THEN 'index'
         WHEN 'S' THEN 'sequence'
         WHEN 'v' THEN 'view'
         WHEN 'm' THEN 'materialized view'
         ELSE 'other'
       END                 AS type, 
       s.n_live_tup        AS total_rows 
FROM   pg_inherits 
       JOIN pg_class parent 
         ON pg_inherits.inhparent = parent.oid 
       JOIN pg_class child 
         ON pg_inherits.inhrelid = child.oid 
       JOIN pg_namespace nmsp_parent 
         ON nmsp_parent.oid = parent.relnamespace 
       JOIN pg_namespace nmsp_child 
         ON nmsp_child.oid = child.relnamespace 
       JOIN pg_stat_user_tables s 
         ON s.relid = child.oid 
WHERE  child.relkind = 'r'
ORDER  BY parent, 
          child; 

26. List ranges for all partitions (and sub-partitions) for a given table
SELECT pt.relname AS partition_name,
       Pg_get_expr(pt.relpartbound, pt.oid, TRUE) AS partition_expression
FROM   pg_class base_tb
       join pg_inherits i
         ON i.inhparent = base_tb.oid
       join pg_class pt
         ON pt.oid = i.inhrelid
WHERE  base_tb.oid = 'public.table_name ' :: regclass;


27. Postgres 12 pg_partition_tree()
Alternatively, can use new PG12 function pg_partition_tree() to display information about partitions. 

SELECT relid, 
       parentrelid, 
       isleaf, 
       level
FROM   Pg_partition_tree('<parent_table_name>');

-----------------------------SECURITY Roles and Privileges--------------------------------------
28. Checking if user is connected is a “superuser”
SELECT usesuper 
FROM   pg_user 
WHERE  usename = CURRENT_USER; 

29. List all users (along with assigned roles) in current database
SELECT usename AS role_name, 
       CASE
         WHEN usesuper 
              AND usecreatedb THEN Cast('superuser, create database' AS
                                   pg_catalog.TEXT) 
         WHEN usesuper THEN Cast('superuser' AS pg_catalog.TEXT) 
         WHEN usecreatedb THEN Cast('create database' AS pg_catalog.TEXT) 
         ELSE Cast('' AS pg_catalog.TEXT) 
       END     role_attributes 
FROM   pg_catalog.pg_user 
ORDER  BY role_name DESC; 