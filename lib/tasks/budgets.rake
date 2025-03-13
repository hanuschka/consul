namespace :budgets do
  task process_preselected_investments: :environment do
    ApplicationLogger.new.info "Calculating preselected investments"
    Budget.process_preselected_investments
  end

  task update_cached_current_phase: :environment do
    ApplicationLogger.new.info "Updating current phase for budgets"
    Budget.update_cached_current_phase
  end
end
