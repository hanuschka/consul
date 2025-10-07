if Rails.env.development?
  Rack::MiniProfiler.config.enabled = lambda { |env, _|
    ENV["DISABLE_MINI_PROFILER"] != "true"
  }
end
