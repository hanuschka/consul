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

  def hidden?
    template["hidden"] == true
  end

  def hidden_until_date
    return nil if template["hidden_until"].blank?

    Date.parse(template["hidden_until"].to_s)
  rescue ArgumentError
    nil
  end

  def hidden_by_date?
    date = hidden_until_date
    return false if hidden?
    return false if date.nil?

    date > Date.current
  end

  def show_visibility_badge?
    hidden? || hidden_by_date?
  end
end
