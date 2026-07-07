class Projekts::GenerateBannerImageJob < ApplicationJob
  queue_as :default

  def perform(projekt_id, user_id, user_prompt = nil, use_projekt_content = true)
    projekt = Projekt.find_by(id: projekt_id)
    return if projekt.blank?

    user = User.find_by(id: user_id)

    Projekts::GenerateBannerImageService.call(
      projekt: projekt,
      user: user,
      user_prompt: user_prompt,
      use_projekt_content: use_projekt_content
    )

    projekt.update_column(:banner_image_generation_status, "completed")
  rescue StandardError => e
    Rails.logger.error("[Projekts::GenerateBannerImageJob] failed: #{e.message}")

    if defined?(Sentry)
      Sentry.capture_exception(e, extra: { projekt_id: projekt_id })
    end

    projekt&.update_column(:banner_image_generation_status, "failed")
  end
end
