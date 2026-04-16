class AiStats::StatCardComponent < ApplicationComponent
  def initialize(title:, tooltip: nil)
    @title = title
    @tooltip = tooltip
  end

  private

  attr_reader :title, :tooltip
end
