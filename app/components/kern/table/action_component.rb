class Kern::Table::ActionComponent < ApplicationComponent
  def initialize(label:, url:, **options)
    @label = label
    @url = url
    @options = options
  end

  def render?
    @options.fetch(:show, true)
  end
end
