module Types
  class ProjektPhaseType < Types::BaseObject
    field :id, ID, null: false
    field :type, String, null: true
    field :active, Boolean, null: true
    field :start_date, GraphQL::Types::ISO8601Date, null: true
    field :end_date, GraphQL::Types::ISO8601Date, null: true
  end
end
