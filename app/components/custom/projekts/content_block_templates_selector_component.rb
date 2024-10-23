class Projekts::ContentBlockTemplatesSelectorComponent < ApplicationComponent
  def description_content_block_templates
    [
      Projekts::ContentBlockTemplates::BlankComponent.new,
      Projekts::ContentBlockTemplates::TitleComponent.new(
        title: example_title
      ),
      Projekts::ContentBlockTemplates::TextComponent.new(
        text: example_description
      ),
      Projekts::ContentBlockTemplates::TextWithTitleComponent.new(
        title: example_title,
        text:  example_description
      ),
      Projekts::ContentBlockTemplates::BulletpointListComponent.new,
      Projekts::ContentBlockTemplates::GreetingComponent.new(
        title: example_title,
        text:  example_description,
        quote: example_description.split[0, 11].join(" "),
        image_url: nil
      ),
      Projekts::ContentBlockTemplates::AccordionComponent.new(
        title: example_title,
        items: accordion_items
      )
    ].compact
  end

  def media_content_block_templates
    [
      Projekts::ContentBlockTemplates::ImageGalleryComponent.new(
        title: example_title,
        template_mode: true,
        images: [
          { url: "https://via.placeholder.com/426x212" },
          { url: "https://via.placeholder.com/426x212" },
          { url: "https://via.placeholder.com/426x212" },
          { url: "https://via.placeholder.com/426x212" }
        ]
      ),
      Projekts::ContentBlockTemplates::SingleImageComponent.new(
        image: { url: "https://via.placeholder.com/426x212" }
      ),
      Projekts::ContentBlockTemplates::ExternalVideoPlayerComponent.new(
        url: nil
      ),
      Projekts::ContentBlockTemplates::ImageSliderComponent.new
    ]
  end

  def card_content_block_templates
    [
      # Projekts::ContentBlockTemplates::ResourceCard::Component.new
      Projekts::ContentBlockTemplates::ColorCardWithImageComponent.new,
      Projekts::ContentBlockTemplates::ColorCardWithImageComponent.new(image_url: "https://via.placeholder.com/200x200")
    ]
  end

  def other_conent_block_templates
    [
      Projekts::ContentBlockTemplates::SuccessComponent.new,
      Projekts::ContentBlockTemplates::WarningComponent.new,
      # Projekts::ContentBlockTemplates::Map::Component.new
    ]
  end

  def example_title
    "Title"
  end

  def example_description
    "Qui nemo id necessitatibus in rerum exercitationem accusantium in minima quo esse quo eius nam iste consequatur quasi qui doloribus officiis omnis nesciunt sit beatae ut est reprehenderit dolore rerum."
  end

  def accordion_items
    [
      {
        title: example_title,
        text: example_description
      },
      {
        title: example_title,
        text: example_description
      },
      {
        title: example_title,
        text: example_description
      }
    ]
  end
end
