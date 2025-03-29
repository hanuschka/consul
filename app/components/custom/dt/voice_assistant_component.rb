class Dt::VoiceAssistantComponent < ApplicationComponent
  delegate :params, to: :helpers

  attr_reader :assistant_codename, :projekt_phase

  def initialize(assistant_codename:, projekt_phase:)
    @assistant_codename = assistant_codename
    @projekt_phase = projekt_phase
  end

  def assistant_iframe_path
    base_url = "#{Rails.application.secrets.dt[:url]}/voice_assistant/#{assistant_codename}"

    uri = URI(base_url)
    params_hash = {
      type: params[:voice_assistant],
      locale: I18n.locale,
      start_with_greeting: params[:start_with_greeting],
      greeting_delay: params[:greeting_delay]
    }.compact

    if Rails.env.development? && params[:dont_start_voice_session] == "true"
      params_hash[:dont_start_voice_session] = "true"
    end

    uri.query = URI.encode_www_form(params_hash)
    uri.to_s
  end

  def assistant_initial_data
    data = {
      projekt: {
        title: projekt_phase.projekt.page.title,
        page_content: projekt_phase.projekt.page_content,
        start_date: projekt_phase.projekt.total_duration_start,
        end_date: projekt_phase.projekt.total_duration_end
      },
      projekt_phase: {
        start_date: projekt_phase.start_date,
        end_date: projekt_phase.end_date
      }
    }

    if show_labels_selector? && projekt_phase.projekt_labels.present?
      data[:projekt_phase][:labels] =
        projekt_phase
          .projekt_labels
          .as_json(only: [:id], methods: [:name])
    end

    if show_sentiments_selector? && projekt_phase.sentiments.present?
      data[:projekt_phase][:sentiments] =
        projekt_phase
          .sentiments
          .as_json(only: [:id, :color], methods: [:name])
          # .as_json(only: [:id], methods: [:name])
    end

    data.to_json
  end

  def show_labels_selector?
    helpers.projekt_phase_feature?(projekt_phase, "form.labels")
  end

  def show_sentiments_selector?
    helpers.projekt_phase_feature?(projekt_phase, "form.sentiments")
  end
end
