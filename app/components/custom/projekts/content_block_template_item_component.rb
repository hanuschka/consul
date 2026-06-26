class Projekts::ContentBlockTemplateItemComponent < ViewComponent::Base
  include StudioTooltipHelper

  def initialize(template_name:, template_dir:)
    @template_name = template_name
    @template_dir = template_dir
  end

  private

  attr_reader :template_name, :template_dir

  def template_path
    "#{template_dir}/#{template_name}"
  end
end
