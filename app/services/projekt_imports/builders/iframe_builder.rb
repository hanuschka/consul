class ProjektImports::Builders::IframeBuilder < ProjektImports::Builders::Base
  def call
    return nil if payload.blank?
    return nil if payload["url"].blank?

    update_setting("option.general.iframe_url", payload["url"])
    update_setting("option.general.iframe_width", payload["width"]) if payload["width"].present?
    update_setting("option.general.iframe_height", payload["height"]) if payload["height"].present?

    true
  end

  private

  def update_setting(key, value)
    setting = phase.settings.find_by(key: key)

    if setting
      setting.update!(value: value.to_s)
    else
      phase.settings.create!(key: key, value: value.to_s)
    end
  rescue ActiveRecord::RecordInvalid => e
    raise ProjektImports::Builders::BuilderError, "iframe setting(#{key}): #{e.message}"
  end
end
