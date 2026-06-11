class Kern::FilterChipsComponent < ApplicationComponent
  # filters: array of { label:, url:, count: (optional), active: (boolean) }
  def initialize(filters:, aria_label: nil)
    @filters = filters
    @aria_label = aria_label
  end

  private

  attr_reader :filters, :aria_label
end
