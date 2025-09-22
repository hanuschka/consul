class Projekts::ContentBlockTemplatesSelectorComponent < ApplicationComponent
  def description_content_block_templates
    %w(
        h3 h4 h5 h6
        text_block_h3_heading
        text_block_two_columns
        textblock
        download_section
        futher_information
        submit_ideas
        favorites_supported
        select_suggestions
    )
  end

  def accordions_content_block_templates
    %w(
      two_items
    )
  end

  def quotes_content_block_templates
    %w(
        picture_on_left_classic
        picture_on_the_right
        image_above_text_below
        image_left_square_larger_size
        image_right_round_purple_color
        classic_white_background
        greeting_image_left_horizontal
    )
  end

  def media_content_block_templates
    %w(
        tile
        one_card
        image_slider_two_images
    )
  end

  def saved_content_blocks
    SavedContentBlock.all.order(:created_at)
  end

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
