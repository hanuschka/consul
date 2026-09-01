class Mitmachbox::Resources::Questions < Mitmachbox::Resources::Base
  def create(survey_id, version_id, prompt:, question_type:, required:, position: nil)
    client.post(
      base_path(survey_id, version_id),
      body: { prompt:, question_type:, required:, position: }.compact
    )
  end

  def update(survey_id, version_id, question_id, attributes)
    client.patch("#{base_path(survey_id, version_id)}/#{segment(question_id)}", body: attributes)
  end

  def delete(survey_id, version_id, question_id)
    client.delete("#{base_path(survey_id, version_id)}/#{segment(question_id)}")
  end

  def reorder(survey_id, version_id, question_ids:)
    client.put("#{base_path(survey_id, version_id)}/reorder", body: { question_ids: })
  end

  private

    def base_path(survey_id, version_id)
      "/surveys/#{segment(survey_id)}/versions/#{segment(version_id)}/questions"
    end
end
