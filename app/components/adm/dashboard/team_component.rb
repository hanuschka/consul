class Adm::Dashboard::TeamComponent < ApplicationComponent
  delegate :empty_state, to: :helpers

  attr_reader :members, :add_url

  def initialize(members:, add_url: nil)
    @members = members
    @add_url = add_url
  end
end
