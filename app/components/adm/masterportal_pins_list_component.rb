class Adm::MasterportalPinsListComponent < ApplicationComponent
  def initialize(projekt_phase:, pins:, pagy:, expanded: false)
    @projekt_phase = projekt_phase
    @pins = pins
    @pagy = pagy
    @expanded = expanded
  end

  def render?
    @projekt_phase.masterportal_pins.exists?
  end

  def total_count
    @pagy.count
  end

  def linked_resource(pin)
    pin.proposal || pin.budget_investment || pin.projekt_point_of_interest_pin
  end

  def linked_resource_label(pin)
    record = linked_resource(pin)
    return nil if record.nil?

    case record
    when Proposal
      t(".linked_resource.proposal")
    when Budget::Investment
      t(".linked_resource.budget_investment")
    when ProjektPointOfInterestPin
      t(".linked_resource.point_of_interest_pin")
    end
  end

  def linked_resource_url(pin)
    record = linked_resource(pin)
    return nil if record.nil?

    case record
    when Proposal
      helpers.proposal_path(record)
    when Budget::Investment
      helpers.budget_investment_path(record.budget, record)
    when ProjektPointOfInterestPin
      nil
    end
  end

  def display_title(pin)
    pin.title.presence || pin.external_id
  end

  def delete_pin_path(pin)
    helpers.destroy_masterportal_pin_adm_projekts_phase_path(
      projekt_phase,
      masterportal_pin_id: pin.id,
      **preserved_listing_params
    )
  end

  def preserved_listing_params
    request_params = helpers.request.query_parameters
    {
      q: request_params["q"].presence,
      view: request_params["view"].presence,
      page: request_params["page"].presence
    }.compact
  end

  def coordinates(pin)
    "#{format_decimal(pin.latitude)}, #{format_decimal(pin.longitude)}"
  end

  def format_decimal(value)
    return "" if value.blank?

    sprintf("%.5f", value.to_f)
  end

  def format_value_for_type(row)
    value = row["value"].to_s
    type = row["type"]

    case type
    when "email"
      helpers.mail_to(value, value, class: "masterportal-pins-list--prop-link")
    when "url"
      helpers.link_to(value, value, target: "_blank", rel: "noopener", class: "masterportal-pins-list--prop-link")
    when "phone"
      helpers.link_to(value, "tel:#{value.gsub(/\s+/, '')}", class: "masterportal-pins-list--prop-link")
    else
      value
    end
  end

  private

    attr_reader :projekt_phase, :pins, :pagy
end
