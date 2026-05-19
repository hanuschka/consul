class Admin::SystemStatsService < ApplicationService
  LOW_DISK_THRESHOLD_GB = 5.0

  def call
    {
      memory: memory_stats,
      disk:   disk_stats,
      cpu:    cpu_stats
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
