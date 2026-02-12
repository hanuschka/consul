class Dt::VoiceAssistantComponent < ApplicationComponent
  delegate :params, to: :helpers

  attr_reader :assistant_codename, :projekt_phase

  def initialize(assistant_codename:, projekt_phase: nil, custom_data: {})
    @assistant_codename = assistant_codename
    @projekt_phase = projekt_phase
    @custom_data = custom_data
  end

  def language
    if Rails.env.development?
      :en
    else
      :de
    end
  end

  def assistant_initial_data
    data = {}

    if projekt_phase.present?
      data.merge!({
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
      })

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
      end
    end

    if @custom_data.present?
      data.merge!(@custom_data)
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
