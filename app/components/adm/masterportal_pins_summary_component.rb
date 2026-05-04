class Adm::MasterportalPinsSummaryComponent < ApplicationComponent
  RESOURCE_NAME_KEYS = {
    "ProjektPhase::ProposalPhase" => ".resource_names.proposals",
    "ProjektPhase::BudgetPhase" => ".resource_names.budget_investments",
    "ProjektPhase::PointOfInterestPhase" => ".resource_names.point_of_interest_pins"
  }.freeze

  def initialize(projekt_phase:, pins_count:)
    @projekt_phase = projekt_phase
    @pins_count = pins_count
  end

  def render?
    @pins_count.to_i.positive?
  end

  def pins_count
    @pins_count.to_i
  end

  def resource_name
    key = RESOURCE_NAME_KEYS[@projekt_phase.type]
    return nil if key.blank?

    t(key)
  end

  def index_path
    helpers.masterportal_pins_adm_projekts_phase_path(@projekt_phase)
  end

  def map_location
    @projekt_phase.map_location
  end

  def feature_collection
    {
      "type" => "FeatureCollection",
      "features" => pins.map { |pin| pin.to_map_feature(include_search_text: false) }
    }
  end

  private

    attr_reader :projekt_phase

    def pins
      @pins ||= projekt_phase
        .masterportal_pins
        .with_attached_icon_image
    end
end
