class Adm::Projekts::Imports::MissingToolsBannerComponent < ApplicationComponent
  def initialize(missing_tools:)
    @missing_tools = missing_tools
  end

  def render?
    missing_tools.any?
  end

  private

  attr_reader :missing_tools

  def feature_text(tool)
    I18n.t("adm.projekts.imports.missing_tools.features.#{tool[:key]}")
  end

  def package_label(tool)
    I18n.t("adm.projekts.imports.missing_tools.package", package: tool[:package])
  end
end
