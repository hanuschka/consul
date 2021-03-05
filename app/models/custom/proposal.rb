require_dependency Rails.root.join("app", "models", "proposal").to_s
class Proposal < ApplicationRecord

  def project_name
    tags.project.first&.name
  end
end
