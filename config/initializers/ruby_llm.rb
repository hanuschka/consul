if Rails.application.secrets.ai&.fetch(:enabled, false) == true
  require 'ruby_llm'
end
