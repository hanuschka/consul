# frozen_string_literal: true

class IdeaOfficerSerializer < BaseSerializer
  attr_reader :officer

  def initialize(officer)
    @officer = officer
  end

  def serialize
    officer_data = officer.as_json(
      only: [
        :id,
        :user_id,
        :created_at,
        :updated_at
      ]
    )

    if officer.user.present?
      officer_data[:user] = {
        id: officer.user.id,
        name: officer.user.name,
        email: officer.user.email,
        username: officer.user.username
      }
    end

    officer_data[:name] = officer.name
    officer_data[:email] = officer.email
    officer_data[:ideas_count] = officer.ideas.count

    officer_data
  end

  def self.serialize_collection(officers)
    officers.map { |officer| new(officer).serialize }
  end
end
