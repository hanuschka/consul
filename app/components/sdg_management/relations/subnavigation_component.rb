class SDGManagement::Relations::SubnavigationComponent < ApplicationComponent
  attr_reader :current

  def initialize(current:)
    @current = current
  end

  private

    def sections
      %w[pending all revised]
    end

    def link_to_section(section)
      link_to t("sdg_management.relations.revision_status.#{section}"),
              path_for(section),
              class: active_style(section)
    end

    def path_for(section)
      url_for(filter: section)
    end

    def active_style(section)
      "is-active" if section == current
    end
end
