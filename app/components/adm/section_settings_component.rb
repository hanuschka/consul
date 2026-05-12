class Adm::SectionSettingsComponent < ApplicationComponent
  # section: String — eine der SectionSetting::SECTIONS (oder beliebige Section-ID)
  # module_setting_keys: Array<String> — Setting-Keys (Booleans) die als Toggles oben gerendert werden (kann leer sein)
  def initialize(section:, module_setting_keys: [])
    @section = section
    @module_settings = module_setting_keys.map { |key| Setting.find_by(key: key) }.compact
    @section_setting = SectionSetting.for_section(section) if SectionSetting::SECTIONS.include?(section)
    @section_contact_people = SectionContactPerson.for_section(section) if SectionContactPerson::SECTIONS.include?(section)
  end

  def render?
    module_settings.any? || section_setting.present? || section_contact_people.present?
  end

  def section_name
    t("adm.section_settings.sections.#{section}", default: section.to_s.humanize)
  end

  private

    attr_reader :section, :module_settings, :section_setting, :section_contact_people

    # Stand-in record for Pundit visibility check on the contact-people block.
    # An unsaved SectionContactPerson scoped to this section lets the policy
    # apply the section-aware area-manager check.
    def contact_person_policy_record
      SectionContactPerson.new(section: section)
    end
end
