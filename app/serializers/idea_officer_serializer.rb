# frozen_string_literal: true

class IdeaOfficerSerializer < BaseSerializer
  attr_reader :officer

  def initialize(officer, client: nil)
    @officer = officer
    @client = client
  end

  def serialize
    officer_data = officer.as_json(
      only: [
        :id,
        :created_at,
        :updated_at
      ]
    )

    if admin_client?
      officer_data.merge!(
        user_id: officer.user_id,
        name: officer.name
      )
    end

    officer_data[:ideas_count] = officer.ideas.count

    officer_data
  end

  def self.serialize_collection(officers, client: nil)
    officers.map { |officer| new(officer, client: client).serialize }
  end
end
