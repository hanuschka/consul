class ProjektPhaseSetting < ApplicationRecord
  SelectableSettingSet = Struct.new(:setting, :options, keyword_init: true)

  SETTING_KINDS = %w[feature option selectable_setting].freeze
  SETTING_BANDS = %w[general form resource].freeze

  AI_GATED_KEYS = %w[
    feature.form.voice_assistant
    feature.general.similar_contributions_check
  ].freeze

  attr_accessor :form_field_disabled, :dependent_setting_ids, :dependent_setting_action

  belongs_to :projekt_phase, touch: true

  validates :projekt_phase_id, :key, presence: true
  validates :key, uniqueness: { scope: :projekt_phase_id }

  default_scope { order(id: :asc) }

  def ai_gated?
    AI_GATED_KEYS.include?(key)
  end

  def kind_prefix
    key.split(".").first
  end

  def kind
    if SETTING_KINDS.include?(kind_prefix)
      kind_prefix
    else
      "feature"
    end
  end

  def band_prefix
    key.split(".").second
  end

  def band
    if SETTING_BANDS.include?(band_prefix)
      band_prefix
    else
      "configuration"
    end
  end

  def translated_name
    I18n.t("custom.projekt_phase_settings.#{projekt_phase.resources_name}.#{key}")
  end

  class << self
    def defaults
      {
        "ProjektPhase::DebatePhase" => {
          "feature.general.only_admins_create_debates": "",

          "feature.form.allow_attached_image": "active",
          "feature.form.allow_attached_documents": "",

          "feature.resource.allow_voting": "active",
          "feature.resource.show_report_button_in_sidebar": "active",
          "feature.resource.show_related_content": "active",
          "feature.resource.show_comments": "active"
        },

        "ProjektPhase::ProposalPhase" => {
          "feature.general.browse_mode_in_phase_footer": "",
          "feature.general.browse_mode_in_phase_footer_by_default": "",
          "feature.general.require_admin_acceptance": "",
          "feature.general.public_kpi_stats": "",
          "feature.general.public_ai_stats": "",
          "feature.general.similar_contributions_check": "",
          "selectable_setting.general.default_order": "random",

          "feature.form.allow_attached_image": "active",
          "feature.form.labels": "",
          "feature.form.use_masterportal_collections_as_labels": "",
          "feature.form.sentiments": "",
          "feature.form.show_map": "active",
          "feature.form.enable_geoman_controls_in_maps": "active",
          "feature.form.allow_attached_documents": "",
          "feature.form.enable_external_video": "",
          "feature.form.voice_assistant": "",
          "feature.form.anonimize_authors": "",
          "option.form.map_features_limit": "1",
          "option.form.description_max_length": "6000",

          "feature.resource.show_video_as_link": "",
          "feature.resource.enable_proposal_notifications_tab": "",
          "feature.resource.enable_proposal_milestones_tab": "",
          "feature.resource.users_can_create_proposals": "active",
          "feature.resource.create_proposal_with_ai": "",
          "feature.resource.allow_voting": "active",
          "feature.resource.conditional_voting": "",
          "feature.resource.quorum_for_proposals": "",
          "feature.resource.enable_up_and_down_voting": "",
          "feature.resource.show_report_button_in_sidebar": "active",
          "feature.resource.show_follow_button_in_proposal_sidebar": "",
          "feature.resource.show_community_button_in_proposal_sidebar": "",
          "feature.resource.show_social_share_buttons": "active",
          "feature.resource.show_related_content": "",
          "feature.resource.show_comments": "active",
          "option.resource.votes_for_proposal_success": 100,
          "option.resource.minimum_supports_to_show": "0",
          "option.resource.max_submissions_per_user": "",
          "option.resource.max_supports_per_user": ""
        },

        "ProjektPhase::VotingPhase" => {
          "feature.resource.wizard_mode": "active",
          "feature.resource.show_on_home_page": "active",
          "feature.resource.show_on_index_page": "active",
          "feature.resource.results_enabled": "",
          "feature.resource.intermediate_poll_results_for_admins": "active",
          "feature.resource.stats_enabled": "",
          "feature.resource.report_visible_for_citizens": "",
          "feature.resource.evaluation_enabled": "",
          "feature.general.public_kpi_stats": "",
          "feature.general.public_ai_stats": "",
          "feature.resource.show_comments": "",
          "feature.resource.show_open_answer_author_name": ""
        },

        "ProjektPhase::BudgetPhase" => {
          "feature.general.browse_mode_in_phase_footer": "",
          "feature.general.browse_mode_in_phase_footer_by_default": "",
          "feature.general.public_kpi_stats": "",
          "feature.general.public_ai_stats": "",
          "feature.general.similar_contributions_check": "",
          "selectable_setting.general.default_order": "random",

          "feature.form.allow_attached_image": "active",
          "feature.form.labels": "",
          "feature.form.use_masterportal_collections_as_labels": "",
          "feature.form.sentiments": "",
          "feature.form.show_map": "active",
          "feature.form.enable_geoman_controls_in_maps": "active",
          "feature.form.allow_attached_documents": "",
          "feature.form.enable_external_video": "",
          "feature.form.show_implementation_option_fields": "",
          "feature.form.show_user_cost_estimate": "",
          "feature.form.voice_assistant": "",
          "option.form.map_features_limit": "1",
          "option.form.description_max_length": "6000",

          "feature.resource.users_can_create_investment_proposals": "active",
          "feature.resource.create_investment_with_ai": "",
          "feature.resource.show_report_button_in_sidebar": "active",
          "feature.resource.show_follow_button_in_sidebar": "",
          "feature.resource.show_community_button_in_sidebar": "",
          "feature.resource.show_social_share_buttons": "active",
          "feature.resource.show_related_content": "",
          "feature.resource.show_comments": "active",
          "feature.resource.conditional_balloting": "",
          "feature.resource.conditional_voting": "",
          "feature.resource.show_video_as_link": "",
          "feature.resource.hide_ballots_count": "",
          "feature.resource.hide_comments_count_order": "",
          "option.resource.max_submissions_per_user": "",
          "option.resource.max_supports_per_user": ""
        },

        "ProjektPhase::CommentPhase" => {
          "feature.general.public_kpi_stats": "",
          "feature.general.public_ai_stats": ""
        },

        "ProjektPhase::QuestionPhase" => {
          "feature.general.show_questions_list": ""
        },

        "ProjektPhase::LivestreamPhase" => {
          "feature.general.show_questions_list": ""
        },

        "ProjektPhase::MilestonePhase" => {
          "feature.general.newest_first": ""
        },

        "ProjektPhase::EventPhase" => {
          "feature.general.reverse_order_for_incoming_events": "",
          "feature.general.show_on_home_page": "active"
        },

        "ProjektPhase::NewsfeedPhase" => {
          "option.general.newsfeed_id": "",
          "option.general.newsfeed_type": ""
        },

        "ProjektPhase::FormularPhase" => {
          "option.general.primary_formular_cutoff_date": "",
          "option.general.submissions_limit": "1"
        },

        "ProjektPhase::IframePhase" => {
          "option.general.iframe_url": "",
          "option.general.iframe_width": "1240",
          "option.general.iframe_height": "800"
        },
        "ProjektPhase::PointOfInterestPhase" => {
          "feature.general.users_can_create_pins": "active",
          "feature.form.use_masterportal_collections_as_labels": "",
          "option.general.max_number_of_pins_per_user": "",
          "option.form.map_features_limit": "1"
        }
      }
    end

    def add_new_settings
      defaults.each do |phase_class, phase_settings|
        phase_default_settings = phase_settings

        phase_class.to_s.constantize.all.find_each do |phase|
          phase_default_settings.each do |key, value|
            phase.settings.create!(key:, value:) unless phase.settings.find_by(key:)
          end
        end
      end
    end

    def destroy_obsolete
      defaults.each do |phase_class, phase_settings|
        phase_default_settings_keys = phase_settings.keys

        phase_class.to_s.constantize.all.find_each do |phase|
          phase.settings.each do |setting|
            setting.destroy! unless phase_default_settings_keys.include?(setting.key.to_sym)
          end
        end
      end
    end
  end

  def enabled?
    value.present?
  end

  def i18n_key
    "custom.projekt_phase_settings.#{projekt_phase.resources_name}.#{key}"
  end
end
