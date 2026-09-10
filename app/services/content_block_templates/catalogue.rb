# Single source of content block templates for every consumer: the selector,
# the AI generation prompts and the projekt import resolver. Returns the shape
# the DT API used to return, so call sites read it unchanged.
#
# Reading from disk rather than over HTTP is the point — the DT round trip was
# what made the selector race its own request timeout.
class ContentBlockTemplates::Catalogue < ApplicationService
  TEMPLATE_ROOT = Rails.root.join("app/views/custom/projekts/dt_content_block_templates").freeze

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
    def categories
      return ContentBlockTemplates::Manifest::CATEGORIES if @section.blank?

      wanted = @section == "newsletter_email" ? "newsletter_email" : "general"

      ContentBlockTemplates::Manifest::CATEGORIES.select { |category| category[:section] == wanted }
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
        "templates" => category[:templates].map { |template| build_template(template) }
      }
    end

    def build_template(template)
      {
        "id" => template[:id],
        "name" => template[:name],
        "description" => template[:description],
        "position" => template[:position],
        "hidden" => template[:hidden],
        "hidden_until" => template[:hidden_until],
        "content" => read_content(template[:file])
      }
    end

    def read_content(file)
      TEMPLATE_ROOT.join(file).read
    end
end
