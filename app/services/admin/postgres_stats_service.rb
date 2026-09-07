# Server-level PostgreSQL statistics for the admin dashboard, queried through
# the existing Active Record (pg) connection so it reuses the pool and
# credentials rather than opening a separate PG::Connection. All queries are
# read-only against system catalogs / stats views and are visible to a normal
# (non-superuser) role.
#
# The metrics are chosen to support connection-pool, Puma, and database tuning:
# connection budget vs max_connections, per-database footprint on a shared
# server, lock waits / idle-in-transaction (connection holders), the key memory
# settings, and work_mem pressure (temp files spilled to disk).
class Admin::PostgresStatsService < ApplicationService
  def call
    return { available: false } unless postgres?

    info = server_info
    counts = connection_counts
    activity = database_activity
    max = info["max_connections"].to_i
    reserved = info["reserved_connections"].to_i
    total = counts[:total]

    {
      available: true,
      version: info["server_version"],
      database: info["database"],
      db_size: info["db_size_pretty"],
      total_storage: total_database_storage,
      uptime_seconds: info["uptime_seconds"].to_i,
      max_connections: max,
      reserved_connections: reserved,
      available_connections: [max - reserved - total, 0].max,
      connections: counts,
      connections_pct: max > 0 ? (total * 100.0 / max).round : 0,
      by_database: connections_by_database,
      config: {
        shared_buffers: info["shared_buffers"],
        effective_cache_size: info["effective_cache_size"],
        work_mem: info["work_mem"],
        maintenance_work_mem: info["maintenance_work_mem"],
        checkpoint_completion_target: info["checkpoint_completion_target"],
        wal_buffers: info["wal_buffers"],
        default_statistics_target: info["default_statistics_target"],
        random_page_cost: info["random_page_cost"],
        effective_io_concurrency: info["effective_io_concurrency"],
        huge_pages: info["huge_pages"],
        min_wal_size: info["min_wal_size"],
        max_wal_size: info["max_wal_size"],
        io_method: info["io_method"],
        io_workers: info["io_workers"]
      },
      activity: activity
    }
  rescue StandardError => e
    { available: false, error: e.message }
  end

  private

    def connection
      ActiveRecord::Base.connection
    end

    def postgres?
      connection.adapter_name.match?(/postgres/i)
    rescue StandardError
      false
    end

    def server_info
      connection.select_one(<<~SQL)
        SELECT
          current_setting('server_version') AS server_version,
          current_setting('max_connections') AS max_connections,
          current_setting('superuser_reserved_connections') AS reserved_connections,
          current_setting('shared_buffers') AS shared_buffers,
          current_setting('effective_cache_size') AS effective_cache_size,
          current_setting('work_mem') AS work_mem,
          current_setting('maintenance_work_mem') AS maintenance_work_mem,
          current_setting('checkpoint_completion_target') AS checkpoint_completion_target,
          current_setting('wal_buffers') AS wal_buffers,
          current_setting('default_statistics_target') AS default_statistics_target,
          current_setting('random_page_cost') AS random_page_cost,
          current_setting('effective_io_concurrency') AS effective_io_concurrency,
          current_setting('huge_pages') AS huge_pages,
          current_setting('min_wal_size') AS min_wal_size,
          current_setting('max_wal_size') AS max_wal_size,
          current_setting('io_method', true) AS io_method,
          current_setting('io_workers', true) AS io_workers,
          current_database() AS database,
          pg_size_pretty(pg_database_size(current_database())) AS db_size_pretty,
          EXTRACT(EPOCH FROM (now() - pg_postmaster_start_time()))::bigint AS uptime_seconds
      SQL
    end

    def connection_counts
      row = connection.select_one(<<~SQL) || {}
        SELECT
          count(*) AS total,
          count(*) FILTER (WHERE state = 'active') AS active,
          count(*) FILTER (WHERE state = 'idle') AS idle,
          count(*) FILTER (WHERE state = 'idle in transaction') AS idle_in_transaction,
          count(*) FILTER (WHERE datname = current_database()) AS this_database,
          count(*) FILTER (WHERE wait_event_type = 'Lock') AS waiting_on_lock,
          COALESCE(EXTRACT(EPOCH FROM max(now() - state_change)
            FILTER (WHERE state = 'idle in transaction')), 0)::int AS longest_idle_txn_seconds,
          COALESCE(EXTRACT(EPOCH FROM max(now() - query_start)
            FILTER (WHERE state = 'active' AND backend_type = 'client backend')), 0)::int AS longest_query_seconds
        FROM pg_stat_activity
      SQL

      {
        total: row["total"].to_i,
        active: row["active"].to_i,
        idle: row["idle"].to_i,
        idle_in_transaction: row["idle_in_transaction"].to_i,
        this_database: row["this_database"].to_i,
        waiting_on_lock: row["waiting_on_lock"].to_i,
        longest_idle_txn_seconds: row["longest_idle_txn_seconds"].to_i,
        longest_query_seconds: row["longest_query_seconds"].to_i
      }
    end

    def total_database_storage
      connection.select_value(<<~SQL)
        SELECT pg_size_pretty(COALESCE(sum(pg_database_size(datname)), 0))
        FROM pg_database
        WHERE datistemplate = false AND has_database_privilege(datname, 'CONNECT')
      SQL
    rescue StandardError
      nil
    end

    def connections_by_database
      connection.select_all(<<~SQL).map { |r| { name: r["name"], count: r["count"].to_i } }
        SELECT COALESCE(datname, '(background)') AS name, count(*) AS count
        FROM pg_stat_activity
        GROUP BY 1
        ORDER BY count DESC
        LIMIT 6
      SQL
    end

    def database_activity
      row = connection.select_one(<<~SQL) || {}
        SELECT
          blks_hit, blks_read, xact_commit, xact_rollback, deadlocks,
          temp_files,
          pg_size_pretty(temp_bytes) AS temp_bytes_pretty
        FROM pg_stat_database
        WHERE datname = current_database()
      SQL

      hit = row["blks_hit"].to_i
      read = row["blks_read"].to_i
      total_blocks = hit + read
      commits = row["xact_commit"].to_i
      rollbacks = row["xact_rollback"].to_i
      transactions = commits + rollbacks

      {
        cache_hit_ratio: total_blocks > 0 ? (hit * 100.0 / total_blocks).round(2) : nil,
        commits: commits,
        rollbacks: rollbacks,
        rollback_pct: transactions > 0 ? (rollbacks * 100.0 / transactions).round(2) : 0,
        deadlocks: row["deadlocks"].to_i,
        temp_files: row["temp_files"].to_i,
        temp_bytes: row["temp_bytes_pretty"]
      }
    end
end
