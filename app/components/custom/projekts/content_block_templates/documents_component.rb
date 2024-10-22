class Projekts::ContentBlockTemplates::DocumentsComponent < ViewComponent::Base
  def initialize(title:, documents:)
    @title = title
    @documents = documents
  end

  def render?
    @documents.present?
  end
end
