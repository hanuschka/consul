class GeozoneStats
  attr_reader :geozone, :participants

  def initialize(geozone, participants)
    @geozone = geozone
    @participants = participants
  end

  def geozone_participants
    if RegisteredAddress::District.present?
      participants.joins(registered_address: :district).where(registered_address_districts: { id: geozone.id })
    else
      participants.where(geozone: geozone)
    end
  end

  def name
    geozone.name
  end

  def count
    geozone_participants.count
  end

  def percentage
    PercentageCalculator.calculate(count, participants.count)
  end
end
