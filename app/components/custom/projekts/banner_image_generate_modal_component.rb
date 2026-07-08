class Projekts::BannerImageGenerateModalComponent < ApplicationComponent
  def initialize(custom_page:)
    @custom_page = custom_page
    @projekt = custom_page.projekt
  end

  def content_blocks_present?
    if !defined?(@content_blocks_present)
      @content_blocks_present =
        ActionController::Base.helpers.strip_tags(@projekt.content_blocks_body).squish.present?
    end

    @content_blocks_present
  end
end
