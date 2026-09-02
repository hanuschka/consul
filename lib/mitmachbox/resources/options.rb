class Mitmachbox::Resources::Options < Mitmachbox::Resources::Base
  def create(survey_id, version_id, question_id, label:, value: nil, position: nil)
    client.post(
      base_path(survey_id, version_id, question_id),
      body: { label:, value:, position: }.compact
    )
  end

  def update(survey_id, version_id, question_id, option_id, attributes)
    client.patch(
      "#{base_path(survey_id, version_id, question_id)}/#{segment(option_id)}",
      body: attributes
    )
  end

  def delete(survey_id, version_id, question_id, option_id)
    client.delete("#{base_path(survey_id, version_id, question_id)}/#{segment(option_id)}")
  end

  private

    def base_path(survey_id, version_id, question_id)
      "/surveys/#{segment(survey_id)}/versions/#{segment(version_id)}/questions/#{segment(question_id)}/options"
    end
end
