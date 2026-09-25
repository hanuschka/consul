class Admin::MemoryStatsService < ApplicationService
  CGROUP_ROOT = "/sys/fs/cgroup".freeze
  UNIFIED_CGROUP_PREFIX = "0::".freeze

  def call
    mem_info = read_meminfo

    return { available: false } if mem_info.empty?

    total_mb = (mem_info["MemTotal"].to_i / 1024.0).round
    free_mb  = (available_kb(mem_info) / 1024.0).round
    used_mb  = total_mb - free_mb
    pct      = total_mb > 0 ? (used_mb * 100.0 / total_mb).round : 0

    {
      available: true,
      total_mb:  total_mb,
      used_mb:   used_mb,
      free_mb:   free_mb,
      pct:       pct,
      swap: swap_stats(mem_info),
      cgroup: cgroup_stats
    }
  end

  private

  def available_kb(mem_info)
    mem_info.fetch("MemAvailable") do
      mem_info.values_at("MemFree", "Buffers", "Cached").sum(&:to_i)
    end
  end

  def swap_stats(mem_info)
    total_mb = (mem_info["SwapTotal"].to_i / 1024.0).round
    free_mb = (mem_info["SwapFree"].to_i / 1024.0).round

    { total_mb: total_mb, used_mb: total_mb - free_mb }
  end

  def cgroup_stats
    cgroup_dir = own_cgroup_dir

    return if cgroup_dir.nil?

    used_mb = bytes_to_mb(File.read(File.join(cgroup_dir, "memory.current")).to_i)
    limit_value = File.read(File.join(cgroup_dir, "memory.max")).strip
    limit_mb = limit_value == "max" ? nil : bytes_to_mb(limit_value.to_i)

    {
      used_mb: used_mb,
      limit_mb: limit_mb,
      pct: limit_mb&.positive? ? (used_mb * 100.0 / limit_mb).round : nil
    }
  rescue StandardError
    nil
  end

  def own_cgroup_dir
    unified_line =
      File.readlines("/proc/self/cgroup").find { |line| line.start_with?(UNIFIED_CGROUP_PREFIX) }

    return if unified_line.nil?

    File.join(CGROUP_ROOT, unified_line.delete_prefix(UNIFIED_CGROUP_PREFIX).strip)
  end

  def bytes_to_mb(bytes)
    (bytes / 1.megabyte.to_f).round
  end

  def read_meminfo
    File.read("/proc/meminfo").lines.each_with_object({}) do |line, h|
      k, v = line.split(":")
      h[k.strip] = v.strip.to_i if v
    end
  rescue StandardError
    {}
  end
end
