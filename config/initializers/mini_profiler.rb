if Rails.env.development?
  Rack::MiniProfiler.config.enabled = ENV["DISABLE_MINI_PROFILER"] != "true"
end
