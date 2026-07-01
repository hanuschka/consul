class Adm::IconRailComponent < ApplicationComponent
  def initialize(current_user:)
    @current_user = current_user
  end

  private

    def items
      sections = helpers.adm_sections
      Adm::SectionVisibility.visible_keys_for(@current_user).map do |key|
        sections[key].merge(key: key)
      end
    end

    def active?(item)
      target_namespace = namespace_for_key(item[:key])
      section = helpers.current_adm_section_namespace
      if target_namespace == "Adm"
        section == "Adm"
      else
        section&.start_with?(target_namespace)
      end
    end

    def namespace_for_key(key)
      key == "administration" ? "Adm" : "Adm::#{key.camelize}"
    end
end
