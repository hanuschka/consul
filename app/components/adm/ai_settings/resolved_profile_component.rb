class Adm::AiSettings::ResolvedProfileComponent < ApplicationComponent
  Tier = Struct.new(:key, :profile, keyword_init: true)

  I18N_SCOPE = "adm.ai_settings.resolved_profile".freeze

  def tiers
    @tiers ||= [
      Tier.new(key: "default", profile: ::Ai::ModelProfile.default),
      Tier.new(key: "fast", profile: ::Ai::ModelProfile.fast),
      Tier.new(key: "ultrafast", profile: ::Ai::ModelProfile.ultrafast)
    ]
  end

  def provider
    ::Ai::Settings.current_llm_provider
  end

  def endpoint_label
    ::Setting["ai.llm_api_endpoint"].presence || t("#{I18N_SCOPE}.endpoint_direct")
  end

  def transport_label
    t("#{I18N_SCOPE}.transports.#{connection.transport}")
  end

  def reasoning_label
    return t("#{I18N_SCOPE}.reasoning_unset") if connection.reasoning_effort.blank?

    connection.reasoning_effort
  end

  def model_label(profile)
    profile.model.presence || t("#{I18N_SCOPE}.model_missing")
  end

  # Every tier resolving to the same model is the whole point of the panel
  # rather than a repetition to hide: it is how an admin sees that choosing a
  # provider replaced the three tiers the platform would otherwise pick between.
  def one_model_for_every_tier?
    tiers.map { |tier| tier.profile.model }.uniq.size == 1
  end

  private

    # Transport and effort are properties of the connection, not of a tier, so
    # they are read off one profile rather than shown three times.
    def connection
      tiers.first.profile
    end
end
