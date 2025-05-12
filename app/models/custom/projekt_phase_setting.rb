class ProjektPhaseSetting < ApplicationRecord
  SelectableSettingSet = Struct.new(:setting, :options, keyword_init: true)

  SETTING_KINDS = %w[feature option selectable_setting].freeze
  SETTING_BANDS = %w[general form resource].freeze

  attr_accessor :form_field_disabled, :dependent_setting_ids, :dependent_setting_action

  belongs_to :projekt_phase, touch: true

  validates :projekt_phase_id, :key, presence: true
  validates :key, uniqueness: { scope: :projekt_phase_id }

  default_scope { order(id: :asc) }

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
          "feature.form.allow_attached_image": "active",
          "feature.form.labels": "",
          "feature.form.sentiments": "",
          "feature.form.show_map": "active",
          "feature.form.enable_geoman_controls_in_maps": "active",
          "feature.form.allow_attached_documents": "",
          "feature.form.enable_external_video": "",
          "feature.resource.show_video_as_link": "",
          "feature.resource.enable_proposal_notifications_tab": "",
          "feature.resource.enable_proposal_milestones_tab": "",

          "feature.general.browse_mode_in_phase_footer": "",
          "feature.general.browse_mode_in_phase_footer_by_default": "",

          "feature.resource.users_can_create_proposals": "active",
          "feature.resource.allow_voting": "active",
          "feature.resource.quorum_for_proposals": "",
          "feature.resource.enable_up_and_down_voting": "",
          "feature.resource.show_report_button_in_sidebar": "active",
          "feature.resource.show_follow_button_in_proposal_sidebar": "",
          "feature.resource.show_community_button_in_proposal_sidebar": "",
          "feature.resource.show_related_content": "",
          "feature.resource.show_comments": "active",
          "option.resource.votes_for_proposal_success": 100,

          "selectable_setting.general.default_order": "random",
        },

        "ProjektPhase::VotingPhase" => {
          "feature.resource.wizard_mode": "active",
          "feature.resource.show_on_home_page": "active",
          "feature.resource.show_on_index_page": "active",
          "feature.resource.results_enabled": "",
          "feature.resource.intermediate_poll_results_for_admins": "active",
          "feature.resource.stats_enabled": "",
          "feature.resource.advanced_stats_enabled": "",
          "feature.resource.show_comments": "active",
          "feature.resource.show_open_answer_author_name": ""
        },

        "ProjektPhase::BudgetPhase" => {
          "feature.form.allow_attached_image": "active",
          "feature.form.labels": "",
          "feature.form.sentiments": "",
          "feature.form.show_map": "active",
          "feature.form.enable_geoman_controls_in_maps": "active",
          "feature.form.allow_attached_documents": "",
          "feature.form.enable_external_video": "",
          "feature.form.show_implementation_option_fields": "",
          "feature.form.show_user_cost_estimate": "",

          "feature.general.browse_mode_in_phase_footer": "",
          "feature.general.browse_mode_in_phase_footer_by_default": "",

          "feature.resource.users_can_create_investment_proposals": "active",
          "feature.resource.show_report_button_in_sidebar": "active",
          "feature.resource.show_follow_button_in_sidebar": "",
          "feature.resource.show_community_button_in_sidebar": "",
          "feature.resource.show_related_content": "",
          "feature.resource.show_comments": "active",
          "feature.resource.conditional_balloting": "",
          "feature.resource.show_video_as_link": "",

          "selectable_setting.general.default_order": "random",
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
        }
      }
    end

    def add_new_settings
      defaults.each do |phase_class, phase_settings|
        phase_default_settings = phase_settings

        phase_class.to_s.constantize.all.find_each do |phase|
          phase_default_settings.each do |key, value|
            phase.settings.create!(key: key, value: value) unless phase.settings.find_by(key: key)
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
