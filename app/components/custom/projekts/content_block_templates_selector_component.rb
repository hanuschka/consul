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
        quote: example_description.split[0,11].join(" "),
        image_url: nil
      ),
      Projekts::ContentBlockTemplates::AccordionComponent.new(
        title: example_title,
        items: accordion_items
      ),
      Projekts::ContentBlockTemplates::ColorCardWithImageComponent.new,
      Projekts::ContentBlockTemplates::ColorCardWithImageComponent.new(image_url: "https://placehold.co/200x200")
    ].compact
  end

  def media_content_block_templates
    [
      Projekts::ContentBlockTemplates::ImageGalleryComponent.new(
        title: example_title,
        images: [
          { url: "https://placehold.co/426x212" },
          { url: "https://placehold.co/426x212" },
          { url: "https://placehold.co/426x212" },
          { url: "https://placehold.co/426x212" }
        ]
      ),
      Projekts::ContentBlockTemplates::SingleImageComponent.new(
        image: { url: "https://placehold.co/426x212" }
      ),
      Projekts::ContentBlockTemplates::ExternalVideoPlayerComponent.new(
        url: nil
      ),
      Projekts::ContentBlockTemplates::ImageSliderComponent.new,
      Projekts::ContentBlockTemplates::SuccessComponent.new,
      Projekts::ContentBlockTemplates::WarningComponent.new,
    ]
  end

  # def saved_content_blocks
  #   current_client.saved_content_blocks.order(:created_at)
  # end

  def example_title
    "Title"
  end

  def example_description
    "Qui nemo id necessitatibus in rerum exercitationem" +
    "accusantium in minima quo esse quo eius nam iste consequatur quasi qui doloribus" +
    "officiis omnis nesciunt sit beatae ut est reprehenderit dolore rerum."
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
