class CustomFeatures
  def self.enabled?(feature_name)
    Rails.application.secrets.dig(feature_name, :enabled) == true
  end
end
