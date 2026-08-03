class Mitmachbox::Resources::Versions < Mitmachbox::Resources::Base
  def create(survey_id)
    client.post("/surveys/#{segment(survey_id)}/versions", body: {})
  end

  def publish(survey_id, version_id)
    client.post("/surveys/#{segment(survey_id)}/versions/#{segment(version_id)}/publish", body: {})
  end

  def find(survey_id, version_id)
    client.get("/surveys/#{segment(survey_id)}/versions/#{segment(version_id)}")
  end
end
