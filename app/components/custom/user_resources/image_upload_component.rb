class UserResources::ImageUploadComponent < ApplicationComponent
  def initialize(f, imageable:)
    @f = f
    @imageable = imageable
  end

  private

    def i18n_scope
      case @imageable
      when Debate
        "debates"
      when Proposal
        "proposals"
      when Offer
        "offers"
      else
        "other"
      end
    end
end
