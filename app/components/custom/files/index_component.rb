class Files::IndexComponent < ApplicationComponent
  def initialize(type:, assets:, endpoint:)
    @type = type
    @assets = assets
    @endpoint = endpoint
  end

  private

    attr_reader :type, :assets, :endpoint
end
