require "etc"

class Admin::SystemStatsService < ApplicationService
  LOW_DISK_THRESHOLD_GB = 5.0

  ALLOCATOR_LIBRARIES = {
    "libjemalloc" => "jemalloc",
    "libtcmalloc" => "tcmalloc",
    "libmimalloc" => "mimalloc"
  }.freeze

  GLIBC_ARENAS_PER_CORE = 8

  def call
    {
      memory:     memory_stats,
      disk:       disk_stats,
      cpu:        cpu_stats,
      db_pool:    db_pool_stats,
      web_server: web_server_stats,
      allocator:  allocator_stats
    }
  end

  private

  def memory_stats
    mem_info = read_meminfo

    return { available: false } if mem_info.empty?

    total_mb = (mem_info["MemTotal"].to_i / 1024.0).round
    free_mb  = (mem_info["MemAvailable"].to_i / 1024.0).round
    used_mb  = total_mb - free_mb
    pct      = total_mb > 0 ? (used_mb * 100.0 / total_mb).round : 0

    {
      available: true,
      total_mb:  total_mb,
      used_mb:   used_mb,
      free_mb:   free_mb,
      pct:       pct
    }
  end

  def disk_stats
    output   = `df -k / 2>/dev/null`.lines.last&.split
    total_kb = output&.fetch(1, 0).to_i
    used_kb  = output&.fetch(2, 0).to_i
    free_kb  = output&.fetch(3, 0).to_i

    return { available: false } if total_kb == 0

    total_gb = (total_kb / 1024.0 / 1024).round(1)
    used_gb  = (used_kb  / 1024.0 / 1024).round(1)
    free_gb  = (free_kb  / 1024.0 / 1024).round(1)
    pct      = (used_kb * 100.0 / total_kb).round

    {
      available: true,
      total_gb:  total_gb,
      used_gb:   used_gb,
      free_gb:   free_gb,
      pct:       pct,
      low:       free_gb < LOW_DISK_THRESHOLD_GB
    }
  end

  def cpu_stats
    cpu_count  = (`nproc 2>/dev/null`.strip.to_i rescue 0)
    load_parts = read_loadavg

    load_1m  = load_parts[0]
    load_5m  = load_parts[1]
    load_15m = load_parts[2]
    pct      = cpu_count > 0 ? [(load_1m.to_f / cpu_count * 100).round, 100].min : 0

    {
      cpu_count: cpu_count,
      load_1m:   load_1m,
      load_5m:   load_5m,
      load_15m:  load_15m,
      pct:       pct
    }
  end

  def db_pool_stats
    size = ActiveRecord::Base.connection_db_config.pool.to_i
    stat = ActiveRecord::Base.connection_pool.stat
    active = stat[:busy].to_i

    {
      available: true,
      size:      size,
      active:    active,
      idle:      stat[:idle].to_i,
      waiting:   stat[:waiting].to_i,
      pct:       size.positive? ? (active * 100.0 / size).round : 0
    }
  rescue StandardError
    { available: false }
  end

  def web_server_stats
    server =
      if defined?(Puma::Server)
        Puma::Server.current
      end

    max_threads = server&.max_threads || Integer(ENV.fetch("RAILS_MAX_THREADS", 5))

    base = {
      available:   true,
      server:      "puma",
      workers:     Integer(ENV.fetch("WEB_CONCURRENCY", Etc.nprocessors)),
      max_threads: max_threads
    }

    return base if server.nil?

    capacity = server.pool_capacity.to_i
    busy     = max_threads - capacity

    base.merge(
      running: server.running.to_i,
      busy:    busy,
      backlog: server.backlog.to_i,
      pct:     max_threads.positive? ? (busy * 100.0 / max_threads).round : 0
    )
  rescue StandardError
    { available: false }
  end

  def allocator_stats
    allocator = detected_allocator

    return { available: false } if allocator.blank?

    glibc_malloc = allocator[:name] == "glibc"
    env_arena_max = malloc_arena_max_env

    {
      available:        true,
      name:             allocator[:name],
      version:          allocator[:version],
      source:           allocator[:source],
      arena_max:        env_arena_max || (glibc_malloc ? glibc_default_arena_max : nil),
      arena_max_source: arena_max_source(env_arena_max, glibc_malloc)
    }
  end

  def detected_allocator
    mapped_allocator || linked_allocator || system_allocator
  end

  def mapped_allocator
    ALLOCATOR_LIBRARIES.each do |soname, name|
      library_path = mapped_library_path(soname)

      next if library_path.blank?

      return {
        name:    name,
        version: version_from_soname(library_path),
        source:  allocator_source(soname)
      }
    end

    nil
  end

  def linked_allocator
    linked_libraries = RbConfig::CONFIG.values_at("MAINLIBS", "LIBS").join(" ")

    ALLOCATOR_LIBRARIES.each do |soname, name|
      flag = "-l#{soname.delete_prefix('lib')}"

      next if !linked_libraries.include?(flag)

      return { name: name, version: nil, source: "ruby_linked" }
    end

    nil
  end

  def system_allocator
    glibc_version = read_glibc_version

    if glibc_version.present?
      return { name: "glibc", version: glibc_version, source: "system_default" }
    end

    if mapped_library_path("ld-musl").present?
      return { name: "musl", version: nil, source: "system_default" }
    end

    nil
  end

  def allocator_source(soname)
    return "ld_preload" if ENV["LD_PRELOAD"].to_s.include?(soname)

    linked_libraries = RbConfig::CONFIG.values_at("MAINLIBS", "LIBS").join(" ")

    return "ruby_linked" if linked_libraries.include?("-l#{soname.delete_prefix('lib')}")

    "loaded"
  end

  def mapped_library_path(soname)
    return @mapped_library_paths[soname] if @mapped_library_paths&.key?(soname)

    @mapped_library_paths ||= {}
    @mapped_library_paths[soname] =
      begin
        match = nil

        File.foreach("/proc/self/maps") do |line|
          path = line.split(" ", 6).last

          if path&.include?(soname)
            match = path.strip
            break
          end
        end

        match
      rescue StandardError
        nil
      end
  end

  def version_from_soname(library_path)
    File.basename(library_path)[/\.so\.([\d.]+)/, 1]
  end

  def malloc_arena_max_env
    value = ENV["MALLOC_ARENA_MAX"].to_i

    value.positive? ? value : nil
  end

  def glibc_default_arena_max
    GLIBC_ARENAS_PER_CORE * Etc.nprocessors
  end

  def arena_max_source(env_arena_max, glibc_malloc)
    return "env" if env_arena_max.present?
    return "glibc_default" if glibc_malloc

    "not_applicable"
  end

  def read_glibc_version
    version = `getconf GNU_LIBC_VERSION 2>/dev/null`[/[\d.]+/]

    return version if version.present?

    `ldd --version 2>/dev/null`.lines.first.to_s[/([\d]+\.[\d.]+)\s*\z/, 1]
  rescue StandardError
    nil
  end

  def read_meminfo
    File.read("/proc/meminfo").lines.each_with_object({}) do |line, h|
      k, v = line.split(":")
      h[k.strip] = v.strip.to_i if v
    end
  rescue StandardError
    {}
  end

  def read_loadavg
    File.read("/proc/loadavg").split.first(3)
  rescue StandardError
    ["N/A", "N/A", "N/A"]
  end
end
