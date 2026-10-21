class Mitmachbox::Resources::Responses < Mitmachbox::Resources::Base
  def create(survey_id, participant_key:, survey_version_id:, answers:)
    client.post("/surveys/#{segment(survey_id)}/responses",
      body: {
        participant_key: participant_key,
        survey_version_id: survey_version_id,
        answers: answers
      })
  end
end
