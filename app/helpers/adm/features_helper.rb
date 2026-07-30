module Adm::FeaturesHelper
  def kobil_credential_badge_style(configured:, required:)
    return "success" if configured
    return "danger" if required

    "warning"
  end
end
