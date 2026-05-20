class VoiceAssistant::CreateSessionService < ApplicationService
  def initialize(codename:, consul_projekt_phase_id:)
    @codename = codename
    @consul_projekt_phase_id = consul_projekt_phase_id
  end

  def call
    response =
      DtApi::Client.new.voice_assistant.create_session(
        codename: @codename,
        consul_projekt_phase_id: @consul_projekt_phase_id,
        data: build_data
      )

    unless response.success?
      Sentry.capture_message(
        "VoiceAssistant create_session failed",
        level: "error",
        extra: {
          status: response.code,
          body: response.parsed_response,
          codename: @codename,
          consul_projekt_phase_id: @consul_projekt_phase_id
        }
      )
    end

    response
  end

  private

  def build_data
    data = {}
    data.merge!(projekt_phase_data) if @consul_projekt_phase_id.present?
    data.merge!(budget_proposal_data) if @codename == "budget_proposal_voice_assistant"
    data.merge!(deficiency_report_data) if @codename == "deficiency_report_voice_assistant"
    data
  end

  def projekt_phase_data
    projekt_phase = ProjektPhase.find(@consul_projekt_phase_id)
    projekt = projekt_phase.projekt

    {
      projekt: {
        name: projekt.page.title,
        page_content: projekt.page_content,
        start_date: projekt.total_duration_start,
        end_date: projekt.total_duration_end
      },
      projekt_phase: {
        start_date: projekt_phase.start_date,
        end_date: projekt_phase.end_date,
        labels: projekt_phase.projekt_labels.as_json(only: [:id, :name]),
        sentiments: projekt_phase.sentiments.as_json(only: [:id, :name, :color])
      }
    }
  end

  def budget_proposal_data
    implementation_performers =
      Budget::Investment.implementation_performers.map { |ip|
        [I18n.t("activerecord.attributes.budget/investment.implementation_performers.#{ip[0]}"), ip[0]]
      }

    { implementation_performers: implementation_performers }
  end

  def deficiency_report_data
    { categories: DeficiencyReport::Category.all.as_json(only: [:id, :name]) }
  end
end
