class Adm::Newsletters::ContentBlockEditorComponent < ApplicationComponent
  def initialize(newsletter:, content_blocks:)
    @newsletter = newsletter
    @content_blocks = content_blocks
  end

  private

    attr_reader :newsletter, :content_blocks

    def create_url
      adm_newsletter_content_blocks_path(newsletter)
    end

    def generate_url
      generate_with_ai_adm_newsletter_content_blocks_path(newsletter)
    end

    def update_url(content_block)
      adm_newsletter_content_block_path(newsletter, content_block)
    end

    def update_position_url(content_block)
      update_position_adm_newsletter_content_block_path(newsletter, content_block)
    end

    def ai_url(content_block)
      change_with_ai_adm_newsletter_content_block_path(newsletter, content_block)
    end

    def block_body_html(content_block)
      AdminWYSIWYGSanitizer.new.sanitize(content_block.body).to_s.html_safe
    end

    def effective_margin(content_block)
      content_block.margin_bottom || ::SiteCustomization::ContentBlock::DEFAULT_MARGIN_BOTTOM
    end

    def default_margin_bottom
      ::SiteCustomization::ContentBlock::DEFAULT_MARGIN_BOTTOM
    end

    def email_origin
      Setting["url"].to_s
    end
end
