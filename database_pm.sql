\o db_nama_db.txt

\qecho "INDEX USAGE STATISTIC : "
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

\qecho "UNUSED INDEX : "
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

\qecho "MISSING INDEX : "
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

\qecho "TOP 10 LONG QUERY : "
SELECT   r.rolname, 
         Round((100 * total_time / Sum(total_time::numeric) OVER ())::numeric, 2) AS percentage_cpu ,
         Round(total_time::numeric, 2)                                            AS total_time, 
         calls, 
         Round(mean_time::numeric, 2) AS mean, 
         Substring(query, 1, 800)     AS short_query 
FROM     pg_stat_statements 
JOIN     pg_roles r 
ON       r.oid = userid 
ORDER BY total_time DESC limit 10;

\qecho "CACHE HIT RATIO TABLE : "
SELECT relname AS "relation", 
       heap_blks_read AS heap_read, 
       heap_blks_hit AS heap_hit, 
       COALESCE((( heap_blks_hit * 100 ) / NULLIF(( heap_blks_hit + heap_blks_read ), 0)),0) AS ratio 
FROM   pg_statio_user_tables
    ORDER BY ratio DESC;

\qecho "CACHE HIT RATIO INDEX : "
SELECT relname AS "relation",
    idx_blks_read AS index_read, 
    idx_blks_hit AS index_hit,
    COALESCE((( idx_blks_hit * 100 ) / NULLIF(( idx_blks_hit + idx_blks_read ), 0)),0) AS ratio
FROM pg_statio_user_indexes
    ORDER BY ratio DESC;

\qecho "20 BIGGEST OBJECT IN DATABASE : "
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

\qecho "LAST AUTO VACCUUM : "
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



