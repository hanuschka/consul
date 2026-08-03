class ProjektImports::CreatePhaseFooterBlocksService < ApplicationService
  AREA_KEY_PREFIXES = {
    "intro_content" => "projekt_footer_tab_explainer",
    "outro_content" => "projekt_footer_tab_outro"
  }.freeze

  attr_reader :phase_entries, :locale

  def initialize(phase_entries:, locale:)
    @phase_entries = Array(phase_entries)
    @locale = locale
  end

  def call
    phase_entries.flat_map { |entry| create_blocks_for(entry) }.compact
  end

  private

  def create_blocks_for(entry)
    phase = entry[:record]
    phase_data = entry[:data] || {}

    AREA_KEY_PREFIXES.map do |field, key_prefix|
      body = html_body(phase_data[field])
      next nil if body.blank?

      upsert_block("#{key_prefix}_#{phase.id}", body)
    end
  end

  # The footer partials read these rows through
  # SiteCustomization::ContentBlock.custom_block_for, which looks them up by
  # name + key + locale alone and leaves projekt_id null. Setting projekt_id
  # here would create a row the partials never find.
  def upsert_block(key, body)
    block = ::SiteCustomization::ContentBlock.find_or_initialize_by(
      name: "custom",
      key: key,
      locale: locale.to_s
    )
    block.body = body
    block.save!

    block
  end

  def html_body(content)
    return nil if content.blank?

    ::AdminWYSIWYGSanitizer.new.sanitize(markdown_renderer.render(content.to_s))
  end

  def markdown_renderer
    @markdown_renderer ||=
      Redcarpet::Markdown.new(
        Redcarpet::Render::HTML.new(
          filter_html: false,
          hard_wrap: true,
          link_attributes: { target: "_blank" }
        ),
        autolink: true,
        lax_spacing: true,
        no_intra_emphasis: true
      )
  end
end
