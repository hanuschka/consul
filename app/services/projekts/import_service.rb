# Rename this class to Projekt::UpdateOfCreateImportredProjekt
class Projekts::ImportService < ApplicationService
  EMAIL_REGEX = /[a-zA-Z0-9.!\#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*/

  attr_reader :projekt, :projekt_params

  def initialize(projekt:, projekt_params:)
    @projekt = projekt
    @projekt_params = projekt_params
    @documents = []
  end

  def call
    @documents = save_documents

    if @projekt.new_record?
      @projekt.name = projekt_params[:title]
      @new_projekt = true
    end

    projekt.assign_attributes(
      total_duration_start: projekt_params[:start_date],
      total_duration_end: projekt_params[:end_date],
      new_content_block_mode: true
    )

    if projekt_params[:images].present?
      @projekt.images = projekt_params[:images]
    end

    @projekt.save!

    create_content_blocks!

    if projekt_params[:title_image].present?
      image = Image.new(
        attachment: projekt_params[:title_image],
        user: User.administrators.first
      )
      @projekt.page.image&.destroy!
      @projekt.page.image = image
    end

    if projekt_params[:greeting_image].present?
      @projekt.greeting_image.attach(projekt_params[:greeting_image])
    end

    create_contact_information_content_block!

    # projekt.update_setting("projekt_feature.general.show_in_navigation")
    # projekt.update_setting("projekt_feature.general.show_in_overview_page")
    # projekt.update_setting("projekt_feature.general.show_in_overview_page_navigation")
    # projekt.update_setting("projekt_feature.general.show_in_homepage")
    # projekt.update_setting("projekt_feature.general.show_in_individual_list")
    # projekt.update_setting("projekt_feature.general.allow_downvoting_comments")
    # projekt.update_setting("projekt_feature.general.set_default_sorting_to_newest")
    # projekt.update_setting("projekt_feature.general.show_in_sidebar_filter")
    # projekt.update_setting("projekt_feature.general.vc_map_enabled")
    update_projekt_setting("projekt_feature.sidebar.show_notification_subscription_toggler", projekt_params[:show_notification_subscription_toggler])
    update_projekt_setting("projekt_feature.sidebar.show_phases_in_projekt_page_sidebar", projekt_params[:show_phases_in_projekt_page_sidebar])
    update_projekt_setting("projekt_feature.sidebar.show_map", projekt_params[:show_map])
    update_projekt_setting("projekt_feature.sidebar.show_navigator_in_projekts_page_sidebar", projekt_params[:show_navigator_in_projekts_page_sidebar])
    update_projekt_setting("projekt_feature.sidebar.projekt_page_sharing", projekt_params[:projekt_page_sharing])

    projekt.page.update!(
      title: projekt_params[:title],
      subtitle: projekt_params[:subtitle],
    )
  end

  def create_content_blocks!
    rendered_sections = content_block_components.map do |content_block_component|
      ApplicationController.render(
        content_block_component,
        layout: false
      ).strip
    end

    rendered_sections
      .reject(&:blank?)
      .map.with_index do |section, index|
        content_block = SiteCustomization::ContentBlock.find_or_initialize_by(
          name: "custom",
          key: "projekt_content_block_#{@projekt.id}_#{index}",
          position: index + 1,
          locale: "de"
        )

        content_block.update!(
          body: section,
          projekt_id: @projekt.id
        )
      end
  end

  def content_block_components
    [
      Projekts::ContentBlockTemplates::TextWithTitleComponent.new(
        title: @projekt_params[:summary_title],
        text: @projekt_params[:summary]
      ),
      Projekts::ContentBlockTemplates::GreetingComponent.new(
        title: (@projekt_params[:greeting_title] || "Grußwort Akkordeon"),
        text: @projekt_params[:greeting],
        quote: @projekt_params[:greeting_quote],
        image_url: @projekt.greeting_image.variant(resize_to_fill: [500, 500])
      ),
      Projekts::ContentBlockTemplates::ImageGalleryComponent.new(
        title: "Projektrelevante Medien",
        images: @projekt.images.map {|i|
          {
            url:
              url_helpers.rails_representation_url(
                i.variant(resize_to_fill: [1500, 750]),
                only_path: true
              ),
            medium_url:
              url_helpers.rails_representation_url(
                i.variant(resize_to_fill: [823, 412]),
                only_path: true
              ),
            thumb_url:
              url_helpers.rails_representation_url(
                i.variant(resize_to_fill: [426, 212]),
                only_path: true
              )
          }
        }
      ),
      Projekts::ContentBlockTemplates::AccordionComponent.new(
        title: "Häufige Fragen",
        items: faq_items
      ),
      Projekts::ContentBlockTemplates::DocumentsComponent.new(
        title: "Projektrelevante Dokumente",
        documents: @documents
      ),
      Projekts::ContentBlockTemplates::AccordionComponent.new(
        title: "Häufige Fragen",
        items: timeline_items
      )
    ].compact
  end

  def faq_items
    # @projekt_params[:faq]
    parse_json_list(@projekt_params[:faq_json])
  end

  def timeline_items
    return if @projekt_params[:timeline_json].blank?

    timeline = parse_json_list(@projekt_params[:timeline_json])

    timeline
      .reject { |e| e[:title].blank? }
      .map.with_index do |entry, index|
        {
          title: "#{entry[:title]} - #{entry[:daterange]}",
          text: entry[:description],
          style: timeline_entry_style(index, timeline.size)
        }
      end
  end

  def timeline_entry_style(index, count)
    if (index == 0) || ((index + 1) == count)
      "background-color:#d8e5f2;color:#004a8f;"
    else
      "background-color:#014779;color:white;"
    end
  end

  def parse_json_list(json_string)
    if json_string.present?
      JSON.parse(json_string).map(&:with_indifferent_access)
    else
      []
    end
  rescue StandardError
    []
  end

  def save_documents
    return if projekt_params[:documents].blank?

    projekt_params[:documents].map do |file|
      document = Document.new
      document.attachment = file
      document.title = document.attachment_file_name
      document.admin = true
      document.user = User.administrators.first
      document.save!
      document
    end
  end

  def create_contact_information_content_block!
    return if @projekt_params[:contact_information].blank?

    content_block = SiteCustomization::ContentBlock.find_or_initialize_by(
      key: "projekt_sidebar_#{@projekt.id}",
      name: "custom",
      locale: "de"
    )

    contact_info = @projekt_params[:contact_information]
    emails_from_contact_info = contact_info.scan(EMAIL_REGEX)

    formated_contact_info =
      contact_info
        .split(/(,{1,}|\.{1,}\s|\.{1,}\z)/)
        .map(&:strip)
        .reject { |e| e.match?(/\A(\s|\.|,)\z/) }
        .join("<br/>")

    emails_from_contact_info.each do |email|
      email_link = <<~HTML
        <a href="mailto:#{email}?subject=Beteiligungsplattform">
          #{email}
        </a>
      HTML

      formated_contact_info.sub!(email, email_link)
    end

    body = <<~HTML
      <div style="
        border: 1px solid #c6c6c6;
        align-items: center;
        align-items: center;
        flex-wrap: wrap;
        border-radius: 5px;
        padding: 1rem; "
      >
        <h5>Ansprechperson</h5>
        #{formated_contact_info}
      </div>
    HTML

    content_block.update!(body: body)
    content_block.save!
  end

  def update_projekt_setting(key, value)
    return if value.blank?

    @projekt.update_bool_setting(key, value)
  end

  def url_helpers
    Rails.application.routes.url_helpers
  end
end
