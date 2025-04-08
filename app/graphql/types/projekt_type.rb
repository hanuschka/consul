module Types
  class ProjektType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: true
    field :active, Boolean, null: true
    field :starts_at, GraphQL::Types::ISO8601Date, null: true
    field :ends_at, GraphQL::Types::ISO8601Date, null: true

    def active
      ApplicationController.helpers.projekt_feature?(object, "main.activate")
    end

    def starts_at
      object.total_duration_start
    end

    def ends_at
      object.total_duration_end
    end
  end
end
