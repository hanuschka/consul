require_dependency Rails.root.join("app", "models", "setting").to_s

class Setting < ApplicationRecord
  AI_GATED_KEYS = %w[
    deficiency_reports.voice_assistant
  ].freeze

  # Meta rejects template names with capitals, spaces or punctuation, and
  # language codes that are not an ISO code with an optional region suffix.
  # Both only fail at send time, so they are checked before they are stored.
  WHATSAPP_TEMPLATE_NAME_FORMAT = /\A[a-z0-9_]{1,512}\z/.freeze
  WHATSAPP_TEMPLATE_LANGUAGE_FORMAT = /\A[a-z]{2}(_[A-Z]{2})?\z/.freeze

  attr_accessor :form_field_disabled, :dependent_setting_ids, :dependent_setting_action

  validate :validate_whatsapp_template_name
  validate :validate_whatsapp_template_language
  validate :validate_whatsapp_address_form

  WHATSAPP_TEMPLATE_NAME_KEYS = %w[
    whatsapp.broadcast_template
    whatsapp.broadcast_card_template
    whatsapp.deadline_approaching_template
    whatsapp.deadline_passed_template
    whatsapp.status_change_template
  ].freeze

  def validate_whatsapp_template_name
    return if !WHATSAPP_TEMPLATE_NAME_KEYS.include?(key)
    return if value.blank?
    return if value.match?(WHATSAPP_TEMPLATE_NAME_FORMAT)

    errors.add(:value, :whatsapp_template_name_invalid)
  end

  def validate_whatsapp_template_language
    return if key != "whatsapp.broadcast_template_language"
    return if value.blank?
    return if value.match?(WHATSAPP_TEMPLATE_LANGUAGE_FORMAT)

    errors.add(:value, :whatsapp_template_language_invalid)
  end

  # The field is free text in /adm, and anything the bot does not recognise
  # falls back to the formal form — silently, which is the same thing as the
  # setting not working. Refused here instead.
  def validate_whatsapp_address_form
    return if key != "whatsapp.address_form"
    return if value.blank?
    return if ::Whatsapp::ADDRESS_FORMS.include?(value.to_s.downcase)

    errors.add(:value, :whatsapp_address_form_invalid)
  end

  def ai_gated?
    AI_GATED_KEYS.include?(key)
  end

  def type
    if %w[feature process proposals map html homepage uploads projekts sdg welcomepage ideas].include? prefix
      prefix
    elsif %w[remote_census].include? prefix
      key.rpartition(".").first
    elsif %w[deficiency_reports].include? prefix
      key.rpartition(".").first
    elsif %w[extended_feature].include? prefix
      key.rpartition(".").first
    elsif %w[extended_option].include? prefix
      key.rpartition(".").first
    elsif %w[extra_fields].include? prefix
      key.rpartition(".").first
    elsif %w[ai].include? prefix
      "ai"
    else
      "configuration"
    end
  end

  class << self
    def all_settings_hash
      unless Current.settings.present?
        Current.settings = Setting.all.pluck(:key, :value).to_h
      end

      Current.settings
    end

    def [](key)
      all_settings_hash[key.to_s]
    end

    def newsletter_brand_color
      self["newsletter_brand_color"].presence || defaults[:newsletter_brand_color]
    end

    def humanized_content_types_for(group, content_types = nil)
      content_types ||= self["uploads.#{group}.content_types"].to_s.split(" ")
      labels = mime_types[group].invert

      content_types
        .map { |content_type| (labels[content_type] || content_type.split("/").last).upcase }
        .join(", ")
    end

    def defaults
      {
        # homepage
        "extended_option.general.title": "Öffentlichkeitsbeteiligung",
        "extended_option.general.subtitle": "in der Stadt CONSUL",

        "welcomepage.usage_stats": true,
        "welcomepage.platform_activity": true,
        "welcomepage.newsletter_subscription": false,
        "welcomepage.projekt_search": false,
        # homepage

        # metadata
        "org_name": "CONSUL", # !!!!!!!!!!!!!!!!
        "url": "https://deine-stadt.de", # Public-facing URL of the app.
        "mailer_from_address": "noreply@consul.dev",
        "mailer_from_name": "CONSUL",
        "meta_title": nil,
        "meta_description": "Die offizielle Beteiligungsplattform der Stadt CONSUL. Die Plattform basiert auf CONSUL Open Source und wurde von demokratie.today modifiziert.",
        "meta_keywords": "consul beteiligung, consul bürgerbeteiligung, consul Beteiligung, consul Bürgerbeteiligung, bürgerbeteiligung, digitale Bürgerbeteiligung, online Bürgerbeteiligung, smart city, smart cities, consul, consul open source, open source, consul project, consul project madrid",
        "facebook_handle": nil,
        "instagram_handle": nil,
        "twitter_handle": nil,
        "twitter_hashtag": nil,
        "telegram_handle": nil,
        "youtube_handle": nil,
        # metadata

        # gdpr
        "extended_feature.gdpr.gdpr_conformity": true,
        "extended_feature.gdpr.link_out_warning": true,
        "extended_feature.gdpr.two_click_iframe_solution": true,
        "extended_option.gdpr.devise_timeout_min": 30,
        "extended_option.gdpr.devise_verification_token_validity_days": 3,
        # gdpr

        # newsletter
        "advanced_newsletter": false,
        # newsletter

        "extended_option.general.city_name": "Consul",

        "feature.featured_proposals": nil,
        "feature.facebook_login": true,
        "feature.google_login": true,
        "feature.twitter_login": true,
        "feature.wordpress_login": false,
        "feature.bund_id_login": false,
        "feature.kobil_login": false,
        "feature.kobil_address_verification": false,
        "feature.public_stats": true,
        "feature.signature_sheets": true,
        "feature.user.recommendations": true,
        "feature.user.recommendations_on_debates": true,
        "feature.user.recommendations_on_proposals": true,
        "feature.community": true,
        "feature.map": nil,
        "feature.allow_attached_documents": true,
        "feature.allow_images": true,
        "feature.help_page": true,
        "feature.remote_translations": nil,
        "feature.translation_interface": nil,
        "feature.remote_census": nil,
        "feature.valuation_comment_notification": true,
        "feature.graphql_api": true,
        "feature.sdg": false,
        "feature.machine_learning": false,
        "feature.matomo": false,
        "feature.melderegister": false,
        "feature.bund_id_verification": false,
        "feature.whatsapp_bot": false,

        # "feature.remove_investments_supports": false,
        "homepage.widgets.feeds.active_projekts": true,
        "homepage.widgets.feeds.polls": true,
        "homepage.widgets.feeds.debates": true,
        "homepage.widgets.feeds.processes": false,
        "homepage.widgets.feeds.proposals": true,
        "homepage.widgets.feeds.expired_projekts": true,
        "homepage.widgets.feeds.investment_proposals": true,
        # Code to be included at the top (inside <body>) of every page
        "html.per_page_code_body": "",
        # Code to be included at the top (inside <head>) of every page (useful for tracking)
        "html.per_page_code_head": "",
        "map.latitude": 48.1372,
        "map.longitude": 11.5754,
        "map.zoom": 10,
        "process.debates": true,
        "process.proposals": true,
        "process.polls": true,
        "process.budgets": true,
        "process.legislation": true,
        "process.projekts": true,
        "process.deficiency_reports": false,
        "process.ideas": false,
        "proposals.successful_proposal_id": nil,
        "proposals.poll_short_title": nil,
        "proposals.poll_description": nil,
        "proposals.poll_link": nil,
        "proposals.email_short_title": nil,
        "proposals.email_description": nil,
        "proposals.poster_short_title": nil,
        "proposals.poster_description": nil,
        # Images and Documents
        "uploads.images.max_size": 4,
        "uploads.images.title.min_length": 4,
        "uploads.images.title.max_length": 80,
        "uploads.images.content_types": "image/jpeg image/png image/gif image/webp",
        "uploads.documents.max_amount": 3,
        "uploads.documents.max_size": 3,
        "uploads.documents.content_types": "application/pdf",
        # Names for the moderation console, as a hint for moderators
        # to know better how to assign users with official positions
        "official_level_1_name": I18n.t("seeds.settings.official_level_1_name"),
        "official_level_2_name": I18n.t("seeds.settings.official_level_2_name"),
        "official_level_3_name": I18n.t("seeds.settings.official_level_3_name"),
        "official_level_4_name": I18n.t("seeds.settings.official_level_4_name"),
        "official_level_5_name": I18n.t("seeds.settings.official_level_5_name"),
        "max_ratio_anon_votes_on_debates": 50,
        "max_votes_for_debate_edit": 1000,
        "max_votes_for_proposal_edit": 1000,
        "comments_body_max_length": 1000,
        "proposal_code_prefix": "CONSUL",
        "votes_for_proposal_success": 10000,
        "months_to_archive_proposals": 12,
        # Users with this email domain will automatically be marked as level 1 officials
        # Emails under the domain's subdomains will also be included
        "email_domain_for_officials": "",
        # CONSUL installation's organization name
        "brand_color": "",
        "newsletter_brand_color": "#004a83",
        "proposal_notification_minimum_interval_in_days": 3,
        "direct_message_max_per_day": 3,
        "mailer_from_deficiency_report_address": "noreply@consul.dev",
        "moderation.reports_notification_email": nil,
        "min_age_to_participate": 16,
        "hot_score_period_in_days": 31,
        "related_content_score_threshold": -0.3,
        "featured_proposals_number": 3,
        "feature.dashboard.notification_emails": nil,
        "machine_learning.comments_summary": false,
        "machine_learning.related_content": false,
        "machine_learning.tags": false,
        "ai.llm_provider": nil,
        "ai.llm_model": nil,
        "ai.llm_api_endpoint": nil,
        "ai.llm_custom_model": nil,
        "ai.whatsapp_transport": nil,
        "postal_codes": "",
        "remote_census.general.endpoint": "",
        "remote_census.request.method_name": "",
        "remote_census.request.structure": "",
        "remote_census.request.document_type": "",
        "remote_census.request.document_number": "",
        "remote_census.request.date_of_birth": "",
        "remote_census.request.postal_code": "",
        "remote_census.response.date_of_birth": "",
        "remote_census.response.postal_code": "",
        "remote_census.response.district": "",
        "remote_census.response.gender": "",
        "remote_census.response.name": "",
        "remote_census.response.surname": "",
        "remote_census.response.valid": "",
        "sdg.process.debates": false,
        "sdg.process.proposals": false,
        "sdg.process.polls": false,
        "sdg.process.budgets": false,
        "sdg.process.legislation": false,
        "sdg.process.projekts": true,

        "welcomepage.share_buttons": "",

        "whatsapp.default_locale": nil,
        "whatsapp.address_form": "sie",
        "whatsapp.welcome_message_enabled": true,
        "whatsapp.welcome_greeting": nil,
        "whatsapp.ice_breaker_1": nil,
        "whatsapp.ice_breaker_2": nil,
        "whatsapp.ice_breaker_3": nil,
        "whatsapp.ice_breaker_4": nil,
        "whatsapp.commands": nil,
        "whatsapp.broadcast_template": nil,
        "whatsapp.broadcast_card_template": nil,
        "whatsapp.deadline_approaching_template": nil,
        "whatsapp.deadline_passed_template": nil,
        "whatsapp.status_change_template": nil,
        "whatsapp.deadline_notifications_enabled": false,
        "whatsapp.broadcast_template_language": "de",
        "whatsapp.auto_broadcast_new_projekts": false,
        "whatsapp.transcription_model": nil,
        "whatsapp.message_retention_days": 90,
        "whatsapp.max_voice_megabytes": 16,

        "deficiency_reports.admins_must_assign_officer": false,
        "deficiency_reports.intake_channel_required_for_on_behalf_of": false,
        "deficiency_reports.officer_groups_only_for_assignment": false,
        "deficiency_reports.ai_categorization": false,
        "deficiency_reports.officers_see_all_reports": false,
        "deficiency_reports.allow_voting": false,
        "deficiency_reports.enable_comments": true,
        "deficiency_reports.intro_text": false,
        "deficiency_reports.show_map": true,
        "deficiency_reports.enable_geoman_controls_in_maps": true,
        "deficiency_reports.map_location_required": true,
        "deficiency_reports.admin_acceptance_required": false,
        "deficiency_reports.image_upload": true,
        "deficiency_reports.document_upload": true,
        "deficiency_reports.external_video": true,
        "deficiency_reports.voice_assistant": false,
        "deficiency_reports.send_feedback_form_link": false,
        "deficiency_reports.show_create_report_button": "active",
        "deficiency_reports.show_homepage_cta": false,
        "deficiency_reports.feature_name": nil,
        "deficiency_reports.create_cta": nil,
        "deficiency_reports.new_form_title": nil,
        "deficiency_reports.new_form_title_placeholder": nil,

        "ideas.admins_must_assign_officer": false,
        "ideas.enable_comments": true,
        "ideas.intro_text": false,
        "ideas.enable_geoman_controls_in_maps": true,
        "ideas.admin_acceptance_required": false,
        "ideas.document_upload": true,
        "ideas.external_video": true,

        # "extended_feature.general.elasticsearch": false,

        "extended_feature.general.extended_editor_for_admins": true,
        "extended_feature.general.extended_editor_for_users": true,
        "extended_feature.general.language_switcher_in_menu": false,
        "extended_feature.general.enable_projekt_events_page": false,
        "extended_feature.general.enable_investments_overview": false,
        "extended_feature.general.enable_google_translate": false,
        # "extended_feature.general.enable_old_design": true,
        "extended_feature.general.users_overview_page": true,
        "extended_feature.general.show_guest_login_links": false,
        # "extended_feature.general.homepage_projekt_search": false,

        "extended_option.general.launch_date": "",
        "extended_option.general.homepage_button_text": "",
        "extended_option.general.homepage_button_link": "",
        "extended_option.general.homepage_navigation_link_color": "#000000",

        "extended_feature.modulewide.enable_categories": true,
        "extended_feature.modulewide.show_number_of_entries_in_modules": true,
        "extended_feature.modulewide.show_affiliation_filter_in_index_sidebar": true,
        "extended_feature.modulewide.hide_comment_replies_by_default": false,
        # temporarily disabled  "extended_feature.modulewide.enable_custom_tags": false,

        "extended_feature.debates.intro_text_for_debates": true,
        "extended_feature.debates.head_image_for_debates": true,
        "extended_feature.debates.enable_projekt_filter": true,
        "extended_feature.debates.enable_my_posts_filter": true,
        "selectable_setting.debates.default_order": "created_at",

        "extended_feature.proposals.intro_text_for_proposals": true,
        "extended_feature.proposals.enable_proposal_support_withdrawal": true,
        "extended_feature.proposals.show_selected_proposals_in_proposal_sidebar": false,
        "extended_feature.proposals.show_suggested_proposals_in_proposal_sidebar": false,
        "extended_feature.proposals.enable_projekt_filter": true,
        "extended_feature.proposals.enable_my_posts_filter": true,
        "selectable_setting.proposals.default_order": "created_at",

        "extended_feature.polls.intro_text_for_polls": true,
        "extended_feature.polls.enable_projekt_filter": true,

        "extended_feature.deficiency_reports.enable_my_posts_filter": true,

        "extended_feature.projekts_overview_page_navigation.show_index_order_all": true,
        "extended_feature.projekts_overview_page_navigation.show_index_order_underway": true,
        "extended_feature.projekts_overview_page_navigation.show_index_order_ongoing": true,
        "extended_feature.projekts_overview_page_navigation.show_index_order_upcoming": true,
        "extended_feature.projekts_overview_page_navigation.show_index_order_expired": true,
        "extended_feature.projekts_overview_page_navigation.show_index_order_individual_list": true,
        "extended_feature.projekts_overview_page_navigation.show_index_order_drafts": true,
        "extended_feature.projekts_overview_page_navigation.show_in_navigation": true,

        "extended_feature.projekts_overview_page_footer.show_in_index_order_all": true,
        "extended_feature.projekts_overview_page_footer.show_in_index_order_underway": true,
        "extended_feature.projekts_overview_page_footer.show_in_index_order_ongoing": true,
        "extended_feature.projekts_overview_page_footer.show_in_index_order_upcoming": true,
        "extended_feature.projekts_overview_page_footer.show_in_index_order_expired": true,
        "extended_feature.projekts_overview_page_footer.show_in_index_order_individual_list": true,

        "extra_fields.registration.extended": false,
        "extra_fields.registration.check_documents": false,

        "extra_fields.verification.check_documents": false,
        "extra_fields.verification.show_data_completeness_status": true,
        "extra_fields.verification.show_verification_status": true,

        # Per-section admin intro text, notice, and notice toggle.
        # Read on each section's adm home; edited under each section's "Einstellungen" tab.
        "adm.ideas.intro_text": nil,
        "adm.ideas.notice_message": nil,
        "adm.ideas.notice_active": nil,
        "adm.deficiency_reports.intro_text": nil,
        "adm.deficiency_reports.notice_message": nil,
        "adm.deficiency_reports.notice_active": nil,
        "adm.projekts.intro_text": nil,
        "adm.projekts.notice_message": nil,
        "adm.projekts.notice_active": nil,
        "adm.moderation.intro_text": nil,
        "adm.moderation.notice_message": nil,
        "adm.moderation.notice_active": nil,
        "adm.valuation.intro_text": nil,
        "adm.valuation.notice_message": nil,
        "adm.valuation.notice_active": nil,
        "adm.landing_pages.intro_text": nil,
        "adm.landing_pages.notice_message": nil,
        "adm.landing_pages.notice_active": nil,
        "adm.officing.intro_text": nil,
        "adm.officing.notice_message": nil,
        "adm.officing.notice_active": nil
      }
    end

    def reset_defaults
      defaults.each { |name, value| self[name] = value }
    end

    def destroy_obsolete
      Setting.all.each{ |setting| setting.destroy unless defaults.keys.include?(setting.key.to_sym) }
    end

    def old_design_enabled?
      !new_design_enabled?
    end

    def new_design_enabled?
      # !old_design_enabled?
      true
    end

    def enabled?(key)
      self[key] == "active"
    end
  end
end
