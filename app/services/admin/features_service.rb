class Admin::FeaturesService < ApplicationService
  def call
    {
      ai:     Admin::AiFeaturesService.call,
      matomo: matomo_feature
    }
  end

  private

  def matomo_feature
    secrets = Rails.application.secrets

    base_url = secrets.matomo_base_url.presence
    site_id  = secrets.matomo_site_id.presence

    {
      enabled:             Setting["feature.matomo"].present?,
      tracking_configured: base_url.present? && site_id.present?,
    }
  end
end
