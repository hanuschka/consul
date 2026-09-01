class Adm::MasterportalCollectionsTaxonomyComponent < ApplicationComponent
  SETTING_KEY = "feature.form.use_masterportal_collections_as_labels".freeze

  def initialize(projekt_phase:, collections:)
    @projekt_phase = projekt_phase
    @collections = collections
  end

  def render?
    @collections.any?
  end

  def switch_setting
    @projekt_phase.settings.find_by(key: SETTING_KEY)
  end

  attr_reader :collections
end
