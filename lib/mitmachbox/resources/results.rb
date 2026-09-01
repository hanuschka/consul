class Mitmachbox::Resources::Results < Mitmachbox::Resources::Base
  def find(survey_id)
    client.get("/surveys/#{segment(survey_id)}/results")
  end

  def export_csv(survey_id)
    client.get_raw("/surveys/#{segment(survey_id)}/results/export")
  end
end
