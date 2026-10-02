class MunicipalPlanTopicSerializer < BaseSerializer
  attr_reader :topic

  def initialize(topic)
    @topic = topic
  end

  def serialize
    {
      id: topic.id,
      name: topic.name,
      given_order: topic.given_order
    }
  end
end
