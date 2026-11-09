class DeficiencyReportIntakeChannelSerializer < BaseSerializer
  attr_reader :intake_channel

  def initialize(intake_channel)
    @intake_channel = intake_channel
  end

  def serialize
    {
      id: intake_channel.id,
      name: intake_channel.name,
      default: intake_channel.default,
      given_order: intake_channel.given_order
    }
  end
end
