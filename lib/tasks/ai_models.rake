namespace :ai_models do
  desc "Refreshes the model catalogue offered on the AI settings page"
  task refresh: :environment do
    Ai::ModelRegistry.refresh
  end
end
