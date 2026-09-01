class Mitmachbox::Resources::Assignments < Mitmachbox::Resources::Base
  BASE_PATH = "/assignments".freeze

  def find(assignment_id)
    client.get("#{BASE_PATH}/#{segment(assignment_id)}")
  end

  def list(status: nil, page: nil, per_page: nil)
    client.get(BASE_PATH, query: { status:, page:, per_page: }.compact)
  end
end
