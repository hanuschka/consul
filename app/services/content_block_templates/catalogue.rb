# Single source of content block templates for every consumer: the selector,
# the AI generation prompts and the projekt import resolver. Returns the shape
# the DT API used to return, so call sites read it unchanged.
#
# Reading from disk rather than over HTTP is the point — the DT round trip was
# what made the selector race its own request timeout.
class ContentBlockTemplates::Catalogue < ApplicationService
  TEMPLATE_ROOT = Rails.root.join("app/views/custom/projekts/dt_content_block_templates").freeze
  DEFAULT_CATEGORY_SECTIONS = %w[general].freeze
  SECTION_CATEGORY_SECTIONS = {
    "newsletter_email" => %w[newsletter_email],
    "sidebar_and_footer" => %w[sidebar_and_footer general]
  }.freeze

  def initialize(section: nil)
    @section = section.presence
  end

  def call
    categories.map { |category| build_category(category) }
  rescue StandardError => e
    Rails.logger.warn("[ContentBlockTemplates::Catalogue] failed to read templates: #{e.message}")
    []
  end

  private

    # The DT endpoint only ever populated "general" and "newsletter_email", and
    # answered "projekt_page" and "sidebar_and_footer" with the general set.
    # Keeping that mapping means the selector's existing sections still resolve.
    # The sidebar cards are added on top of it for "sidebar_and_footer" only,
    # ahead of the general set so the selector opens on them.
    def categories
      return ContentBlockTemplates::Manifest::CATEGORIES if @section.blank?

      wanted_sections = SECTION_CATEGORY_SECTIONS.fetch(@section, DEFAULT_CATEGORY_SECTIONS)

      wanted_sections.flat_map do |wanted_section|
        ContentBlockTemplates::Manifest::CATEGORIES.select { |category| category[:section] == wanted_section }
      end
    end

    def build_category(category)
      {
        "category" => {
          "id" => category[:id],
          "name" => category[:name_de],
          "name_de" => category[:name_de],
          "name_en" => category[:name_en],
          "section" => category[:section],
          "position" => category[:position]
        },
        "templates" => category[:templates].filter_map { |template| build_template(template) }
      }
    end

    def build_template(template)
      content = read_content(template[:file])

      return nil if content.nil?

      {
        "id" => template[:id],
        "name" => template[:name],
        "description" => template[:description],
        "position" => template[:position],
        "hidden" => template[:hidden],
        "hidden_until" => template[:hidden_until],
        "content" => content
      }
    end

    # One unreadable file drops only its own template, not the whole catalogue.
    def read_content(file)
      TEMPLATE_ROOT.join(file).read
    rescue SystemCallError => e
      Rails.logger.warn("[ContentBlockTemplates::Catalogue] skipped #{file}: #{e.message}")
      nil
    end
end
