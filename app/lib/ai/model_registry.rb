# The models each provider offers, as the daily ai_models:refresh task last
# saved them to the ruby_llm_models table. A refresh downloads the catalogue
# and rewrites every row in one transaction, so it never runs in a request:
# two admins opening the AI settings page at once raced each other into the
# table's unique index on (provider, model_id).
module Ai::ModelRegistry
  # Read from the table on every call rather than through RubyLLM.models,
  # which each process loads once and would keep serving until a restart.
  # An empty table falls back to the registry bundled with the gem.
  def self.chat_model_ids(provider)
    RubyLLM::Models.new
      .by_provider(provider.to_sym)
      .chat_models
      .sort_by { |model| model.created_at || Time.new(2000) }.reverse
      .map(&:id)
  end

  def self.refresh
    RubyLLM.models.refresh
  end
end
