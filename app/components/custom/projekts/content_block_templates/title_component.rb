class Projekts::ContentBlockTemplates::TitleComponent < ViewComponent::Base
  def initialize(title:)
    @title = title
  end
end
