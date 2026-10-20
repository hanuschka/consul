module ContentBlockVisibilityParams
  extend ActiveSupport::Concern

  private

    def content_block_visibility_params
      attributes = SiteCustomization::ContentBlock::VISIBILITY_ATTRIBUTES

      params.slice(*attributes).permit(*attributes).to_h
    end
end
