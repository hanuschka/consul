class Projekts::DtContentBlockTemplateItemComponent < ViewComponent::Base
  def initialize(template:)
    @template = template
  end

  private

  attr_reader :template

  def template_id
    template["id"]
  end

  def template_name
    template["name"]
  end

  def template_content
    template["content"]
  end
end
