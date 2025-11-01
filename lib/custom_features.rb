class CustomFeatures
  def self.enabled?(feature_name)
    Rails.application.secrets.custom_features&.dig(feature_name, :enabled) == true
  end
end
