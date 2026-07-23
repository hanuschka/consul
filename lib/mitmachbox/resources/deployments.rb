class Mitmachbox::Resources::Deployments < Mitmachbox::Resources::Base
  BASE_PATH = "/deployments".freeze

  def list(assignment_id: nil, survey_id: nil, status: nil, page: nil, per_page: nil)
    client.get(
      BASE_PATH,
      query: { assignment_id:, survey_id:, status:, page:, per_page: }.compact
    )
  end

  def create(assignment_id:, survey_id:, location: nil)
    client.post(BASE_PATH, body: { assignment_id:, survey_id:, location: })
  end

  def find(deployment_id)
    client.get("#{BASE_PATH}/#{segment(deployment_id)}")
  end

  def update(deployment_id, attributes)
    client.patch("#{BASE_PATH}/#{segment(deployment_id)}", body: attributes)
  end

  def delete(deployment_id)
    client.delete("#{BASE_PATH}/#{segment(deployment_id)}")
  end
end
