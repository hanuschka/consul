class Adm::AttributeEditorComponent < ApplicationComponent
  SETTING_TYPES = [Setting, ProjektSetting, ProjektPhaseSetting].freeze

  def initialize(record, attribute, kind, **options)
    @record = record
    @attribute = attribute
    @kind = kind.to_sym
    @options = options
  end

  def path
    return @options[:path] if @options[:path].present?

    adm_attribute_path(record_type: record_type_key.tr("/", "-"), id: @record.id)
  end

  def label
    text = @options[:label].presence || I18n.t(i18n_key(:label), default: @attribute.to_s.humanize)
    field_required? ? "#{text} *" : text
  end

  def description
    return nil if update_not_permitted?

    @options[:description].presence || I18n.t(i18n_key(:description), default: nil)
  end

  DESCRIPTION_ALLOWED_ATTRIBUTES =
    (Rails::Html::SafeListSanitizer.allowed_attributes.to_a + %w[target rel]).freeze

  def sanitized_description
    helpers.sanitize(description, attributes: DESCRIPTION_ALLOWED_ATTRIBUTES)
  end

  def note
    @options[:note].presence || ai_gated_note || not_permitted_note
  end

  def update_not_permitted?
    return false if update_policy.nil?

    !update_policy.update?
  end

  def ai_gated?
    return true if @options[:ai_gated] == true

    @record.respond_to?(:ai_gated?) && @record.ai_gated?
  end

  def component_for_type
    case @kind
    when :boolean
      Adm::AttributeEditors::BooleanComponent
    when :string
      Adm::AttributeEditors::StringComponent
    when :text
      Adm::AttributeEditors::TextComponent
    when :rich_text
      Adm::AttributeEditors::RichTextComponent
    when :image
      Adm::AttributeEditors::ImageComponent
    when :video
      Adm::AttributeEditors::VideoComponent
    when :color
      Adm::AttributeEditors::ColorComponent
    when :select
      Adm::AttributeEditors::SelectComponent
    when :content_types
      Adm::AttributeEditors::ContentTypesComponent
    when :date
      Adm::AttributeEditors::DateComponent
    else
      raise "Unsupported attribute editor kind: #{@kind}"
    end
  end

  def aria_options
    {
      labelledby: "#{dom_id(@record)}_#{@attribute}_label",
      describedby: "#{dom_id(@record)}_#{@attribute}_description"
    }
  end

  def disabled?
    @options[:disabled] == true || ai_gated_disabled?
  end

  def input_disabled?
    disabled? || update_not_permitted?
  end

  def wide?
    @options[:wide] == true
  end

  def stacked?
    @kind == :rich_text
  end

  def inline?
    @options[:inline] == true
  end

  def divider?
    @options.fetch(:divider, true)
  end

  def hide_label?
    @options[:hide_label] == true
  end

  private

    def update_policy
      return @update_policy if defined?(@update_policy)

      policy_class = @options[:policy_class] || Adm::PolicyLookup.policy_class_if_known(@record)
      @update_policy = policy_class&.new(current_user, @record)
    end

    def ai_gated_disabled?
      ai_gated? && !Ai::Settings.ai_available?
    end

    def ai_gated_note
      return nil if !ai_gated_disabled?

      I18n.t("adm.ai_required_note")
    end

    def not_permitted_note
      return nil if !update_not_permitted?

      I18n.t("adm.not_authorized_edit")
    end

    def i18n_key(type)
      if @record.is_a?(::ProjektPhaseSetting)
        "projekt_phase_setting.#{@record.projekt_phase.name}.#{@record.key}#{'_description' if type == :description}"
      elsif setting_type?
        "setting.#{@record.key}#{'_description' if type == :description}"
      elsif @record.is_a?(::SiteCustomization::Image) || @record.is_a?(::SiteCustomization::Video)
        "adm.attribute_editor.#{record_type_key}.#{@record.name}_#{type}"
      elsif @record.is_a?(::SiteCustomization::ContentBlock) && @record.key.present?
        ["adm.attribute_editor", record_type_key, @record.key, "#{@attribute}_#{type}"].join(".")
      else
        ["adm.attribute_editor", record_type_key, suffix, "#{@attribute}_#{type}"].compact.join(".")
      end
    end

    def record_type_key
      @record_type_key ||= @record.class.base_class.name.underscore
    end

    def suffix
      return unless @record.is_a?(::SiteCustomization::Page)

      return "projekt" if @record.projekt.present?
      return "landing" if @record.landing?
    end

    def setting_type?
      SETTING_TYPES.any? { |type| @record.is_a?(type) }
    end

    def field_required?
      return false unless @record.class.respond_to?(:validators_on)

      @record.class.validators_on(@attribute).any? do |v|
        v.is_a?(ActiveModel::Validations::PresenceValidator) &&
          v.options.except(:message).empty?
      end
    end
end
