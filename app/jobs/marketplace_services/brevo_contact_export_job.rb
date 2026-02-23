class MarketplaceServices::BrevoContactExportJob < ApplicationJob
  queue_as :default

  def perform(user_id, export_type)
    MarketplaceServices::BrevoContactExporter.call(user_id, export_type)
  end
end
