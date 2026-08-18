Rails.application.config.after_initialize do
  require_dependency "deepl"

  Deepl.report_free_key
end
