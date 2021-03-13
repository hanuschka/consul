require_dependency Rails.root.join("app", "models", "proposal").to_s
class Proposal < ApplicationRecord
  _validators.reject! { |attribute, _| attribute == :responsible_name }
  def project_name
    tags.project.first&.name
  end
end
