require_dependency Rails.root.join("app", "models", "debate").to_s

class Debate
  include Imageable

  def project_name
    tags.project.first&.name
  end
end
