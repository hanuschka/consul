class Whatsapp::Flows::AttachSharedLocationService < Whatsapp::Flows::BaseService
  # The pin the citizen shared through WhatsApp's own picker, written onto the
  # draft.
  #
  # It replaces whatever PersistDraftService may have geocoded out of the free
  # text rather than joining it — a position the citizen chose outranks one
  # inferred from their wording — which is `MapLocation.create_pin!`'s own
  # behaviour, shared with the geocoder so the two cannot write different pins.
  def initialize(conversation:, latitude:, longitude:)
    super(conversation: conversation)
    @latitude = latitude
    @longitude = longitude
  end

  # Returns true when the pin was written, so the caller knows whether to say so
  # before publishing.
  def call
    return false if draft_resource.blank?
    return false if @latitude.blank? || @longitude.blank?

    MapLocation.create_pin!(
      mappable: draft_resource, latitude: @latitude, longitude: @longitude
    )

    true
  rescue StandardError => e
    report(e, "location attach")

    false
  end

  private
end
