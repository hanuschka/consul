class MarketplaceServices::BrevoContactExportJob < ApplicationJob
  queue_as :default

  def perform(user_id, export_type, email = nil)
    MarketplaceServices::BrevoContactExporter.call(user_id, export_type, email)
  end
end
