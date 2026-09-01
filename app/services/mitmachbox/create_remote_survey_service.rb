class Mitmachbox::CreateRemoteSurveyService < ApplicationService
  TITLE_MAX_LENGTH = 120

  def initialize(projekt_phase:, acting_user:)
    @projekt_phase = projekt_phase
    @acting_user = acting_user
  end

  def call
    survey = client.surveys.create(title: survey_title)

    @projekt_phase.update_columns(mitmachbox_survey_id: survey["id"].to_s)

    survey
  end

  private

    def client
      @client ||= Mitmachbox::Client.new(acting_user: @acting_user)
    end

    def survey_title
      suffix = " (##{@projekt_phase.id})"

      [projekt_title, @projekt_phase.title].map(&:presence).compact
        .join(" – ")
        .truncate(TITLE_MAX_LENGTH - suffix.length) + suffix
    end

    def projekt_title
      projekt = @projekt_phase.projekt

      projekt.page&.title.presence || projekt.title
    end
end
