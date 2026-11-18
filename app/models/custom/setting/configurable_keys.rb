# The instance settings an API client with the configuration right may change.
# A key that is not listed here cannot be changed through the API at all —
# sender addresses, custom head/body code, AI providers, census and registry
# configuration, login and verification providers stay out on purpose.
module Setting::ConfigurableKeys
  GROUPS = %w[
    metadata branding homepage modules module_options gdpr uploads map moderation
  ].freeze

  # Bought and switched through the app.demokratie.today connection; the
  # public API leaves them to that connection.
  DT_APP_SWITCH_KEYS = %w[
    feature.facebook_login
    feature.google_login
    feature.twitter_login
    feature.wordpress_login
    feature.matomo
  ].freeze

  LAUNCH_DATE_FORMAT = "%d.%m.%Y".freeze

  class << self
    def all
      @all ||= build_all.index_by(&:key).freeze
    end

    def find(key)
      all[key.to_s]
    end

    def boolean_keys
      all.values.select(&:boolean?).map(&:key)
    end

    # What the internal enable/disable endpoint of the DT connection may switch.
    def internal_switches
      @internal_switches ||= (DT_APP_SWITCH_KEYS + boolean_keys).uniq.to_h do |key|
        [key, find(key) || ConfigurableKey.new(key, group: "internal", type: :boolean)]
      end.freeze
    end

    private

      def build_all
        metadata_keys + branding_keys + homepage_keys + module_keys +
          module_option_keys + gdpr_keys + upload_keys + map_keys + moderation_keys
      end

      def metadata_keys
        [
          entry("org_name", group: "metadata", type: :string),
          entry("url", group: "metadata", type: :url),
          entry("meta_title", group: "metadata", type: :string, allow_blank: true),
          entry("meta_description", group: "metadata", type: :text, allow_blank: true, max_length: 1000),
          entry("meta_keywords", group: "metadata", type: :text, allow_blank: true, max_length: 1000),
          entry("handbook.url", group: "metadata", type: :url, allow_blank: true),
          entry("extended_option.general.city_name", group: "metadata", type: :string, allow_blank: true),
          entry("facebook_handle", group: "metadata", type: :string, allow_blank: true, max_length: 100),
          entry("instagram_handle", group: "metadata", type: :string, allow_blank: true, max_length: 100),
          entry("twitter_handle", group: "metadata", type: :string, allow_blank: true, max_length: 100),
          entry("twitter_hashtag", group: "metadata", type: :string, allow_blank: true, max_length: 100),
          entry("telegram_handle", group: "metadata", type: :string, allow_blank: true, max_length: 100),
          entry("youtube_handle", group: "metadata", type: :string, allow_blank: true, max_length: 100)
        ]
      end

      def branding_keys
        [
          entry("brand_color", group: "branding", type: :color, allow_blank: true),
          entry("newsletter_brand_color", group: "branding", type: :color, allow_blank: true),
          entry(
            "extended_option.general.homepage_navigation_link_color",
            group: "branding", type: :color, allow_blank: true
          )
        ]
      end

      def homepage_keys
        [
          entry("extended_option.general.title", group: "homepage", type: :string, allow_blank: true),
          entry("extended_option.general.subtitle", group: "homepage", type: :string, allow_blank: true),
          entry(
            "extended_option.general.homepage_button_text",
            group: "homepage", type: :string, allow_blank: true
          ),
          entry(
            "extended_option.general.homepage_button_link",
            group: "homepage", type: :link, allow_blank: true
          ),
          entry(
            "extended_option.general.launch_date",
            group: "homepage", type: :date, allow_blank: true, date_format: LAUNCH_DATE_FORMAT
          ),
          *boolean_group("homepage", %w[
            welcomepage.usage_stats
            welcomepage.platform_activity
            welcomepage.newsletter_subscription
            welcomepage.projekt_search
            welcomepage.share_buttons
            homepage.widgets.feeds.active_projekts
            homepage.widgets.feeds.polls
            homepage.widgets.feeds.debates
            homepage.widgets.feeds.processes
            homepage.widgets.feeds.proposals
            homepage.widgets.feeds.expired_projekts
            homepage.widgets.feeds.investment_proposals
          ])
        ]
      end

      def module_keys
        boolean_group("modules", %w[
          process.debates
          process.proposals
          process.polls
          process.budgets
          process.legislation
          process.projekts
          process.deficiency_reports
          process.municipal_plans
          process.ideas
          advanced_newsletter
          feature.featured_proposals
          feature.signature_sheets
          feature.user.recommendations
          feature.user.recommendations_on_debates
          feature.user.recommendations_on_proposals
          feature.community
          feature.map
          feature.allow_attached_documents
          feature.allow_images
          feature.translation_interface
          feature.valuation_comment_notification
          feature.graphql_api
          feature.sdg
          feature.dashboard.notification_emails
          sdg.process.debates
          sdg.process.proposals
          sdg.process.polls
          sdg.process.budgets
          sdg.process.legislation
          sdg.process.projekts
        ])
      end

      def module_option_keys
        [
          *boolean_group("module_options", %w[
            extended_feature.general.extended_editor_for_admins
            extended_feature.general.extended_editor_for_users
            extended_feature.general.language_switcher_in_menu
            extended_feature.general.enable_projekt_events_page
            extended_feature.general.enable_investments_overview
            extended_feature.general.enable_google_translate
            extended_feature.general.users_overview_page
            extended_feature.modulewide.enable_categories
            extended_feature.modulewide.show_number_of_entries_in_modules
            extended_feature.modulewide.show_affiliation_filter_in_index_sidebar
            extended_feature.modulewide.hide_comment_replies_by_default
            extended_feature.debates.intro_text_for_debates
            extended_feature.debates.head_image_for_debates
            extended_feature.debates.enable_projekt_filter
            extended_feature.debates.enable_my_posts_filter
            extended_feature.proposals.intro_text_for_proposals
            extended_feature.proposals.enable_proposal_support_withdrawal
            extended_feature.proposals.show_selected_proposals_in_proposal_sidebar
            extended_feature.proposals.show_suggested_proposals_in_proposal_sidebar
            extended_feature.proposals.enable_projekt_filter
            extended_feature.proposals.enable_my_posts_filter
            extended_feature.polls.intro_text_for_polls
            extended_feature.polls.enable_projekt_filter
            extended_feature.deficiency_reports.enable_my_posts_filter
            extended_feature.projekts_overview_page_navigation.show_index_order_all
            extended_feature.projekts_overview_page_navigation.show_index_order_underway
            extended_feature.projekts_overview_page_navigation.show_index_order_ongoing
            extended_feature.projekts_overview_page_navigation.show_index_order_upcoming
            extended_feature.projekts_overview_page_navigation.show_index_order_expired
            extended_feature.projekts_overview_page_navigation.show_index_order_individual_list
            extended_feature.projekts_overview_page_navigation.show_index_order_drafts
            extended_feature.projekts_overview_page_navigation.show_in_navigation
            extended_feature.projekts_overview_page_footer.show_in_index_order_all
            extended_feature.projekts_overview_page_footer.show_in_index_order_underway
            extended_feature.projekts_overview_page_footer.show_in_index_order_ongoing
            extended_feature.projekts_overview_page_footer.show_in_index_order_upcoming
            extended_feature.projekts_overview_page_footer.show_in_index_order_expired
            extended_feature.projekts_overview_page_footer.show_in_index_order_individual_list
            deficiency_reports.admins_must_assign_officer
            deficiency_reports.intake_channel_required_for_on_behalf_of
            deficiency_reports.officer_groups_only_for_assignment
            deficiency_reports.ai_categorization
            deficiency_reports.officers_see_all_reports
            deficiency_reports.allow_voting
            deficiency_reports.enable_comments
            deficiency_reports.intro_text
            deficiency_reports.show_map
            deficiency_reports.enable_geoman_controls_in_maps
            deficiency_reports.map_location_required
            deficiency_reports.admin_acceptance_required
            deficiency_reports.image_upload
            deficiency_reports.document_upload
            deficiency_reports.external_video
            deficiency_reports.voice_assistant
            deficiency_reports.send_feedback_form_link
            deficiency_reports.separate_reporter_answer
            deficiency_reports.show_create_report_button
            deficiency_reports.show_homepage_cta
            ideas.admins_must_assign_officer
            ideas.enable_comments
            ideas.intro_text
            ideas.enable_geoman_controls_in_maps
            ideas.admin_acceptance_required
            ideas.document_upload
            ideas.external_video
            municipal_plans.officers_see_all
            municipal_plans.auto_archive
            municipal_plans.procedure_steps
            proposals.email_on_official_answer
          ]),
          entry(
            "deficiency_reports.feature_name",
            group: "module_options", type: :string, allow_blank: true
          ),
          entry(
            "deficiency_reports.create_cta",
            group: "module_options", type: :string, allow_blank: true
          ),
          entry(
            "selectable_setting.debates.default_order",
            group: "module_options", type: :select, options: Debate.debates_orders
          ),
          entry(
            "selectable_setting.proposals.default_order",
            group: "module_options", type: :select, options: Proposal.proposals_orders
          ),
          entry(
            "email_templates.recipient_greeting",
            group: "module_options", type: :select, options: User::RECIPIENT_GREETING_OPTIONS
          ),
          entry("proposal_code_prefix", group: "module_options", type: :string, max_length: 20),
          entry("votes_for_proposal_success", group: "module_options", type: :integer, min: 1),
          entry("months_to_archive_proposals", group: "module_options", type: :integer, min: 1),
          entry("featured_proposals_number", group: "module_options", type: :integer, min: 0),
          entry("max_ratio_anon_votes_on_debates", group: "module_options", type: :integer, min: 0, max: 100),
          entry("max_votes_for_debate_edit", group: "module_options", type: :integer, min: 0),
          entry("max_votes_for_proposal_edit", group: "module_options", type: :integer, min: 0),
          entry("comments_body_max_length", group: "module_options", type: :integer, min: 1),
          entry(
            "proposal_notification_minimum_interval_in_days",
            group: "module_options", type: :integer, min: 0
          ),
          entry("direct_message_max_per_day", group: "module_options", type: :integer, min: 0),
          entry("min_age_to_participate", group: "module_options", type: :integer, min: 0, max: 120),
          entry("hot_score_period_in_days", group: "module_options", type: :integer, min: 1),
          entry("related_content_score_threshold", group: "module_options", type: :decimal, min: -1, max: 1)
        ]
      end

      def gdpr_keys
        [
          *boolean_group("gdpr", %w[
            extended_feature.gdpr.gdpr_conformity
            extended_feature.gdpr.link_out_warning
            extended_feature.gdpr.two_click_iframe_solution
          ]),
          entry("extended_option.gdpr.devise_timeout_min", group: "gdpr", type: :integer, min: 1, max: 1440),
          entry(
            "extended_option.gdpr.devise_verification_token_validity_days",
            group: "gdpr", type: :integer, min: 1, max: 365
          )
        ]
      end

      def upload_keys
        [
          entry("uploads.images.max_size", group: "uploads", type: :integer, min: 1, max: 100),
          entry("uploads.images.title.min_length", group: "uploads", type: :integer, min: 0),
          entry("uploads.images.title.max_length", group: "uploads", type: :integer, min: 1),
          entry(
            "uploads.images.content_types",
            group: "uploads", type: :multi_select, options: Setting.mime_types["images"].values
          ),
          entry("uploads.documents.max_amount", group: "uploads", type: :integer, min: 0),
          entry("uploads.documents.max_size", group: "uploads", type: :integer, min: 1, max: 100),
          entry(
            "uploads.documents.content_types",
            group: "uploads", type: :multi_select, options: Setting.mime_types["documents"].values
          )
        ]
      end

      def map_keys
        [
          entry("map.latitude", group: "map", type: :decimal, min: -90, max: 90),
          entry("map.longitude", group: "map", type: :decimal, min: -180, max: 180),
          entry("map.zoom", group: "map", type: :integer, min: 0, max: 22)
        ]
      end

      def moderation_keys
        (1..5).map do |level|
          entry("official_level_#{level}_name", group: "moderation", type: :string, allow_blank: true)
        end
      end

      def entry(key, **options)
        ConfigurableKey.new(key, **options)
      end

      def boolean_group(group, keys)
        keys.map do |key|
          entry(
            key, group:, type: :boolean, ai_gated: Setting::AI_GATED_KEYS.include?(key)
          )
        end
      end
  end
end
