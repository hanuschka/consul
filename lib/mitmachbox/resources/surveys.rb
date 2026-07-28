class Mitmachbox::Resources::Surveys < Mitmachbox::Resources::Base
  BASE_PATH = "/surveys".freeze

  def create(title:, description: nil)
    client.post(BASE_PATH, body: { title:, description: }.compact)
  end

  def find(survey_id)
    client.get("#{BASE_PATH}/#{segment(survey_id)}")
  end

  def update(survey_id, attributes)
    client.patch("#{BASE_PATH}/#{segment(survey_id)}", body: attributes)
  end

  def update_state(survey_id, state)
    client.put("#{BASE_PATH}/#{segment(survey_id)}/state", body: { state: })
  end
end
