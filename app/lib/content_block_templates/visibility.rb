# Whether a catalogue template is hidden in the template selector, either for
# good ("hidden") or until a date ("hidden_until"). The selector still lists
# hidden templates for admins, with a badge; every AI flow that picks templates
# on its own must leave them out.
module ContentBlockTemplates::Visibility
  def self.hidden?(template)
    template["hidden"] == true || hidden_until_future?(template)
  end

  def self.hidden_until_date(template)
    hidden_until = template["hidden_until"]
    return nil if hidden_until.blank?

    Date.parse(hidden_until.to_s)
  rescue ArgumentError
    nil
  end

  def self.hidden_until_future?(template)
    date = hidden_until_date(template)
    return false if date.nil?

    date > Date.current
  end

  def self.without_hidden_templates(templates_by_category)
    templates_by_category.map do |category_data|
      visible_templates = Array(category_data["templates"]).reject { |template| hidden?(template) }

      category_data.merge("templates" => visible_templates)
    end
  end
end
