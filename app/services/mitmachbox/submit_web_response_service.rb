class Mitmachbox::SubmitWebResponseService
  def self.call(projekt_phase:, user:, survey_version_id:, answers:)
    new(projekt_phase: projekt_phase, user: user,
        survey_version_id: survey_version_id, answers: answers).call
  end

  def initialize(projekt_phase:, user:, survey_version_id:, answers:)
    @projekt_phase = projekt_phase
    @user = user
    @survey_version_id = survey_version_id
    @answers = answers
  end

  def call
    receipt = client.responses.create(
      @projekt_phase.mitmachbox_survey_id,
      participant_key: participant_key,
      survey_version_id: @survey_version_id,
      answers: @answers
    )
    record_participation!

    receipt["status"]
  end

  private

    def participant_key
      Mitmachbox.participant_key(user_id: @user.id, survey_version_id: @survey_version_id)
    end

    def record_participation!
      MitmachboxParticipation.create!(
        projekt_phase: @projekt_phase, user: @user, survey_version_id: @survey_version_id
      )
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      nil
    end

    def client
      @client ||= Mitmachbox::Client.new(anonymous: true)
    end
end
