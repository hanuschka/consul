# SDG goals and targets are seeded from the same fixed list on every instance,
# so their code identifies one both here and on another instance, where their id
# would not.
class Projekts::Copying::Serializing::SdgCodeSerializer < ApplicationService
  MODEL_BY_TYPE = {
    "SDG::Goal" => SDG::Goal,
    "SDG::Target" => SDG::Target
  }.freeze

  def self.resolve(nodes)
    Array(nodes).filter_map do |node|
      model = MODEL_BY_TYPE[node["type"]]
      next if model.blank?

      model.find_by(code: node["code"])
    end
  end

  def initialize(source:)
    @source = source
  end

  def call
    source.sdg_relations.filter_map do |relation|
      next if MODEL_BY_TYPE.exclude?(relation.related_sdg_type)

      code = relation.related_sdg&.code
      next if code.blank?

      { "type" => relation.related_sdg_type, "code" => code.to_s }
    end
  end

  private

    attr_reader :source
end
