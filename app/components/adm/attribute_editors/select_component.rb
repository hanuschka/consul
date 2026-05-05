class Adm::AttributeEditors::SelectComponent < Adm::AttributeEditorComponent
  def initialize(record, attribute, **options)
    @record = record
    @attribute = attribute
    @options = options
    @select_options = options[:select_options] || []
  end

  def translated_select_options
    @select_options.map do |option|
      if option.is_a?(Array)
        option
      else
        [I18n.t("#{i18n_key(:label)}_options.#{option}", default: option.to_s.humanize), option]
      end
    end
  end

  def aria_attributes
    attrs = {}
    attrs[:labelledby] = @options[:labelledby] if @options[:labelledby].present?
    attrs[:describedby] = @options[:describedby] if @options[:describedby].present?
    attrs
  end
end
