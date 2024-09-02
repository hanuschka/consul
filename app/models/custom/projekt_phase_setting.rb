class ProjektPhaseSetting < ApplicationRecord
  SETTING_KINDS = %w[feature option].freeze
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

  class << self
    def defaults
      {
        "ProjektPhase::DebatePhase" => {
          base: {
            "feature.general.only_admins_create_debates": "",

            "feature.form.allow_attached_image": "active",
            "feature.form.allow_attached_documents": "",

            "feature.resource.allow_voting": "active",
            "feature.resource.allow_downvoting": "active",
            "feature.resource.show_report_button_in_sidebar": "active",
            "feature.resource.show_related_content": "active",
            "feature.resource.show_comments": "active"
          }
        },

        "ProjektPhase::ProposalPhase" => {
          form_author: {
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
          },

          user_functions: {
            "feature.general.only_admins_create_proposals": "",
            "feature.resource.allow_voting": "active",
            "feature.resource.enable_proposal_support_withdrawal": "active",
            "feature.resource.quorum_for_proposals": "",
            "feature.resource.show_report_button_in_sidebar": "active",
            "feature.resource.show_follow_button_in_proposal_sidebar": "",
            "feature.resource.show_community_button_in_proposal_sidebar": "",
            "feature.resource.show_related_content": "",
            "feature.resource.show_comments": "active",
            "option.resource.votes_for_proposal_success": 100
          }
        },

        "ProjektPhase::VotingPhase" => {
          base: {
            "feature.resource.wizard_mode": "active",
            "feature.resource.show_on_home_page": "active",
            "feature.resource.show_on_index_page": "active",
            "feature.resource.results_enabled": "",
            "feature.resource.intermediate_poll_results_for_admins": "active",
            "feature.resource.stats_enabled": "",
            "feature.resource.advanced_stats_enabled": "",
            "feature.resource.show_comments": "active",
            "feature.resource.show_open_answer_author_name": ""
          }
        },

        "ProjektPhase::BudgetPhase" => {
          base: {
            "feature.general.only_admins_create_investment_proposals": "",
            "feature.general.show_results_after_first_vote": "",
            "feature.general.show_relative_ballotting_results": "",

            "feature.form.allow_attached_image": "active",
            "feature.form.show_implementation_option_fields": "",
            "feature.form.show_user_cost_estimate": "",
            "feature.form.show_map": "active",
            "feature.form.enable_geoman_controls_in_maps": "active",
            "feature.form.allow_attached_documents": "",

            "feature.resource.remove_investments_supports": "active",
            "feature.resource.show_report_button_in_sidebar": "active",
            "feature.resource.show_follow_button_in_sidebar": "",
            "feature.resource.show_community_button_in_sidebar": "",
            "feature.resource.show_related_content": "",
            "feature.resource.enable_investment_milestones_tab": "",
            "feature.resource.show_comments": "active"
          }
        },

        "ProjektPhase::QuestionPhase" => {
          base: {
            "feature.general.show_questions_list": ""
          }
        },

        "ProjektPhase::LivestreamPhase" => {
          base: {
            "feature.general.show_questions_list": ""
          }
        },

        "ProjektPhase::MilestonePhase" => {
          base: {
            "feature.general.newest_first": ""
          }
        },

        "ProjektPhase::NewsfeedPhase" => {
          base: {
            "option.general.newsfeed_id": "",
            "option.general.newsfeed_type": ""
          }
        },

        "ProjektPhase::FormularPhase" => {
          base: {
            "feature.general.only_registered_users": "",
            "option.general.primary_formular_cutoff_date": ""
          }
        }
      }
    end

    def add_new_settings
      defaults.each do |phase_class, phase_settings|
        phase_default_settings = phase_settings.values.reduce(:merge)

        phase_class.to_s.constantize.all.find_each do |phase|
          phase_default_settings.each do |key, value|
            phase.settings.create!(key: key, value: value) unless phase.settings.find_by(key: key)
          end
        end
      end
    end

    def destroy_obsolete
      defaults.each do |phase_class, phase_settings|
        phase_default_settings_keys = phase_settings.values.reduce(:merge).keys

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
end
