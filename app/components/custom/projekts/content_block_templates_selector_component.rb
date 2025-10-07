class Projekts::ContentBlockTemplatesSelectorComponent < ApplicationComponent
  def basic_content_templates
    %w(
      h3 h4 h5 h6
      text_block_h3_heading
      text_block_two_columns
      textblock
      accordion
      bullet_points
      download_section
      futher_information
      submit_ideas
      favorites_supported
      select_suggestions

      quote_picture_on_left_classic
      quote_picture_on_the_right
      quote_image_above_text_below
      quote_image_left_square_larger_size
      quote_image_right_round_purple_color
      quote_picture_left_square
      quote_classic_white_background
      quote_greeting_image_left_horizontal
      quote_greeting_centered_above
      quote_greeting_image_left_vertical
      quote_greeting_image_right_vertical
      quote_greeting_round_picture_right
    )
  end

  def status_and_notes_templates
    %w(
      callout_warning
      callout_warning_2
      callout_warning_3
      callout_success
      callout_success_2
      callout_alert
      callout_alert_2
      callout_alert_3
      callout_info
      callout_info_2
      callout_info_3

      timeline_1
      timeline_2
      timeline_3
      timeline_4

      kpi_1
      kpi_2
      kpi_3
    )
  end

  def teasers_and_promotions
    %w(
    )
  end

  def media_and_resources_templates
    %w(
      single_image
      gallery
      tile
      one_card
      image_slider
    )
  end

  def messages_content_block_templates
    %w(
      success
      warning
    )
  end

  def saved_content_blocks
    SavedContentBlock.all.order(:created_at)
  end
end
