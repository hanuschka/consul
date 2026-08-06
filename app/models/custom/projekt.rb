class Projekt < ApplicationRecord
  OVERVIEW_PAGE_NAME = "projekt_overview_page".freeze
  PHASE_PRELOAD_FOR_CONTROLLER = {
    "proposals" => { proposal_phases: [:individual_group_values, :settings] },
    "debates" => { debate_phases: [:individual_group_values, :settings] },
    "polls" => { voting_phases: [:individual_group_values, :settings, :polls] },
    "processes" => {
      legislation_phases: [:individual_group_values, :settings, :legislation_process]
    }
  }.freeze

  # The settings that SQL scopes filter on live as columns; every other
  # projekt setting stays a `projekt_settings` row.
  KEY_TO_COLUMN = {
    "projekt_feature.main.activate" => :activated,
    "projekt_feature.general.show_in_navigation" => :show_in_navigation,
    "projekt_feature.general.show_in_overview_page" => :show_in_overview_page,
    "projekt_feature.general.show_in_overview_page_navigation" => :show_in_overview_page_navigation,
    "projekt_feature.general.show_in_homepage" => :show_in_homepage,
    "projekt_feature.general.show_in_individual_list" => :show_in_individual_list,
    "projekt_feature.general.show_in_sidebar_filter" => :show_in_sidebar_filter
  }.freeze

  include Milestoneable
  acts_as_paranoid column: :hidden_at
  include ActsAsParanoidAliases
  include Mappable
  include ActiveModel::Dirty
  include SDG::Relatable
  include Taggable
  include Searchable
  include Notifiable
  include SectionTrackable

  translates :description
  include Globalizable

  has_secure_token :preview_code

  has_many :children, -> { order(order_number: :asc) }, class_name: "Projekt", foreign_key: "parent_id",
    inverse_of: :parent, dependent: :nullify

  has_many :third_level_children, -> { order(order_number: :asc) }, class_name: "Projekt", foreign_key: "top_level_projekt_id",
    inverse_of: :top_level_projekt, dependent: :nullify
  belongs_to :parent, class_name: "Projekt", optional: true
  belongs_to :top_level_projekt, class_name: "Projekt", optional: true

  has_one :page, class_name: "SiteCustomization::Page", dependent: :destroy
  has_one :projekt_evaluation, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy

  has_many :projekt_settings, dependent: :destroy

  has_many :projekt_phases, dependent: :destroy
  has_many :active_and_visible_projekt_phases, -> { active.frontend_visible }, class_name: "ProjektPhase"
  has_many :debate_phases, class_name: "ProjektPhase::DebatePhase", dependent: :destroy
  has_many :proposal_phases, class_name: "ProjektPhase::ProposalPhase", dependent: :destroy
  has_many :budget_phases, class_name: "ProjektPhase::BudgetPhase", dependent: :destroy
  has_many :comment_phases, class_name: "ProjektPhase::CommentPhase", dependent: :destroy
  has_many :voting_phases, class_name: "ProjektPhase::VotingPhase", dependent: :destroy
  has_many :milestone_phases, class_name: "ProjektPhase::MilestonePhase", dependent: :destroy
  has_many :projekt_notification_phases, class_name: "ProjektPhase::ProjektNotificationPhase",
    dependent: :destroy
  has_many :newsfeed_phases, class_name: "ProjektPhase::NewsfeedPhase", dependent: :destroy
  has_many :event_phases, class_name: "ProjektPhase::EventPhase", dependent: :destroy
  has_many :legislation_phases, class_name: "ProjektPhase::LegislationPhase", dependent: :destroy
  has_many :question_phases, class_name: "ProjektPhase::QuestionPhase", dependent: :destroy
  has_many :argument_phases, class_name: "ProjektPhase::ArgumentPhase", dependent: :destroy
  has_many :livestream_phases, class_name: "ProjektPhase::LivestreamPhase", dependent: :destroy

  has_and_belongs_to_many :geozone_affiliations, class_name: "Geozone",
    after_add: :touch_updated_at, after_remove: :touch_updated_at
  has_and_belongs_to_many :registered_address_district_affiliations,
    class_name: "RegisteredAddress::District",
    join_table: "projekts_registered_address_districts",
    foreign_key: "projekt_id",
    association_foreign_key: "registered_address_district_id",
    after_add: :touch_updated_at, after_remove: :touch_updated_at
  has_and_belongs_to_many :individual_group_values,
    after_add: :touch_updated_at, after_remove: :touch_updated_at
  has_and_belongs_to_many :hard_individual_group_values, -> { hard }, class_name: "IndividualGroupValue"

  has_many :debates, through: :debate_phases, source: :resources
  has_many :proposals, through: :proposal_phases, source: :resources
  has_many :budgets, through: :budget_phases
  has_many :polls, through: :voting_phases
  has_many :projekt_arguments, through: :argument_phases
  has_many :projekt_livestreams, through: :livestream_phases
  has_many :projekt_notifications, through: :projekt_notification_phases
  has_many :projekt_events, through: :event_phases
  has_many :legislation_processes, through: :legislation_phases

  belongs_to :author, -> { with_hidden }, class_name: "User", inverse_of: :projekts

  has_many :map_layers, as: :mappable, dependent: :destroy
  has_many :navbar_items, dependent: :destroy

  # has_many :projekt_labels, dependent: :destroy #remove

  has_many :projekt_manager_assignments, dependent: :destroy
  has_many :projekt_managers, through: :projekt_manager_assignments
  accepts_nested_attributes_for :projekt_manager_assignments
  accepts_nested_attributes_for :page

  has_many :subscriptions, -> { where(projekt_subscriptions: { active: true }) },
    class_name: "ProjektSubscription", dependent: :destroy, inverse_of: :projekt
  has_many :subscribers, through: :subscriptions, source: :user

  has_many :content_blocks, class_name: "SiteCustomization::ContentBlock",
    dependent: :destroy, inverse_of: :projekt

  has_one_attached :greeting_image
  has_many_attached :images

  belongs_to :landing_page, class_name: 'SiteCustomization::Page', optional: true

  delegate :image, to: :page, allow_nil: true
  delegate :url, to: :page, allow_nil: true

  after_create :create_corresponding_page, :set_order, :create_default_settings,
    :copy_map_settings, :ensure_other_projekts_order_integrity, :assign_author_as_manager

  after_update :sync_children_activated, if: :saved_change_to_activated?
  after_update :mirror_setting_columns_to_legacy_rows

  after_save :recalculate_subtree_levels, if: :saved_change_to_parent_id?

  before_save :assign_top_level_projekt_from_parent
  before_save :sync_published_at

  before_create :initialize_content_updated_at
  before_update :bump_content_updated_at

  after_save :reset_visible_projekt_ids_cache
  after_destroy :reset_visible_projekt_ids_cache

  after_commit :broadcast_publication_on_whatsapp

  after_update :sync_for_global_overview_if_changed #, on: :update
  # after_touch :sync_for_global_overview_if_changed
  after_destroy :sync_destroy_for_global_overview

  after_destroy :ensure_projekt_order_integrity

  def should_be_exported_for_global_overview?
    if  Rails.env.development? && Rails.application.secrets.dt[:disable_sync]
      return false
    end

    InternalApiClient.active_dt? && (
      on_dt_global_overview? || acceptable_to_be_exported_for_global_overview?
    )
  end

  validates :color, format: { with: /\A#[\da-f]{6}\z/i }, allow_blank: true
  validates :name, presence: true

  attribute :order_number, :integer, default: 0
  attribute :new_content_block_mode, :boolean, default: true
  attribute :show_content_background, :boolean, default: false

  enum import_file_status: {
    never_run: "never_run",
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed"
  }, _prefix: true, _default: "never_run"

  scope :regular, -> { where(special: false) }
  scope :with_order_number, -> { where.not(order_number: nil).order(order_number: :asc) }
  scope :sort_by_order_number, -> {
    order(:level, :order_number)
  }

  scope :top_level, -> {
    with_order_number
      .where(parent: nil)
  }

  # ---------------------------------------------------------------------------
  # SWITCH: where the 7 promoted settings are read from.
  #
  #   true  — read the `projekts` columns (current behaviour). The
  #           `projekt_settings` rows are still written on every change and
  #           serve as a synced backup; nothing queries them.
  #   false — read the `projekt_settings` rows again, exactly as before the
  #           columns existed.
  #
  # To switch: flip this constant and re-deploy. No migration, no data fix —
  # both stores are kept in sync in both directions (see
  # `mirror_setting_columns_to_legacy_rows` here and
  # `ProjektSetting#sync_promoted_projekt_column`), so either side is current
  # at any time. Everything below that depends on it is in this file, plus the
  # editor visibility in `ProjektAdminActions#edit` and
  # `adm/projekts/projekts/visibility.html.erb`.
  # ---------------------------------------------------------------------------
  USE_SETTING_COLUMNS = true

  if USE_SETTING_COLUMNS
    scope :activated, -> { where(activated: true) }
    scope :not_activated, -> { where(activated: false) }
    scope :show_in_overview_page, -> { where(show_in_overview_page: true) }
    scope :show_in_homepage, -> { where(show_in_homepage: true) }
    scope :show_in_sidebar_filter, -> { where(show_in_sidebar_filter: true) }
    scope :show_in_navigation, -> { where(show_in_navigation: true) }
    scope :show_in_overview_page_navigation, -> { where(show_in_overview_page_navigation: true) }
    scope :in_individual_list, -> { where(show_in_individual_list: true) }
    scope :not_in_individual_list, -> { where(show_in_individual_list: false) }
  else
    scope :activated, -> { with_setting_value("projekt_feature.main.activate", "active") }
    scope :not_activated, -> { with_setting_value("projekt_feature.main.activate", [nil, ""]) }
    scope :show_in_overview_page, -> {
      with_setting_value("projekt_feature.general.show_in_overview_page", "active")
    }
    scope :show_in_homepage, -> {
      with_setting_value("projekt_feature.general.show_in_homepage", "active")
    }
    scope :show_in_sidebar_filter, -> {
      with_setting_value("projekt_feature.general.show_in_sidebar_filter", "active")
    }
    scope :show_in_navigation, -> {
      with_setting_value("projekt_feature.general.show_in_navigation", "active")
    }
    scope :show_in_overview_page_navigation, -> {
      with_setting_value("projekt_feature.general.show_in_overview_page_navigation", "active")
    }
    scope :in_individual_list, -> {
      with_setting_value("projekt_feature.general.show_in_individual_list", "active")
    }
    scope :not_in_individual_list, -> {
      with_setting_value("projekt_feature.general.show_in_individual_list", [nil, ""])
    }
  end

  # Only used while USE_SETTING_COLUMNS is false. The alias keeps each setting's
  # join distinct so several of these scopes can chain in one query.
  def self.with_setting_value(key, value)
    join_alias = "ps_#{key.tr(".", "_")}"

    joins("INNER JOIN projekt_settings #{join_alias} ON projekts.id = #{join_alias}.projekt_id")
      .where("#{join_alias}.key": key, "#{join_alias}.value": value)
  end

  scope :current, ->(timestamp = Time.zone.today) {
    activated
      .where("total_duration_start IS NULL OR total_duration_start <= ?", timestamp)
      .where("total_duration_end IS NULL OR total_duration_end >= ?", timestamp)
  }

  # scope :current_for_import, ->(timestamp = Time.zone.today) {
  #   where("total_duration_end IS NULL OR total_duration_end >= ?", timestamp)
  # }

  scope :expired, ->(timestamp = Time.zone.today) {
    activated
      .where("total_duration_end < ?", timestamp)
  }

  scope :index_order_all, ->() {
    activated
      .with_published_custom_page
      .show_in_overview_page
      .order("projekts.created_at DESC")
  }

  scope :index_order_underway, ->(timestamp = Time.zone.today) {
    current(timestamp)
      .with_published_custom_page
      .show_in_overview_page
      .not_in_individual_list
      .where(current_regular_phase_exists(timestamp).or(consider_underway_setting_exists))
      .order("projekts.created_at DESC")
  }

  scope :index_order_ongoing, ->(timestamp = Time.zone.today) {
    current(timestamp)
      .with_published_custom_page
      .show_in_overview_page
      .not_in_individual_list
      .where(Arel::Nodes::Not.new(current_regular_phase_exists(timestamp)))
      .order("projekts.created_at DESC")
  }

  scope :index_order_upcoming, ->(timestamp = Time.zone.today) {
    activated
      .with_published_custom_page
      .show_in_overview_page
      .not_in_individual_list
      .where("total_duration_start > ?", timestamp)
      .order("projekts.created_at DESC")
  }

  scope :index_order_expired, ->(timestamp = Time.zone.today) {
    expired
      .with_published_custom_page
      .show_in_overview_page
      .not_in_individual_list
      .order("projekts.created_at DESC")
  }

  scope :index_order_individual_list, -> {
    with_published_custom_page
      .show_in_overview_page
      .in_individual_list
      .order("projekts.created_at DESC")
  }

  scope :index_order_drafts, -> {
    not_activated
      .order("projekts.created_at DESC")
  }

  def self.current_regular_phase_exists(timestamp = Time.zone.today)
    ProjektPhase
      .regular_phases
      .current(timestamp)
      .where(ProjektPhase.arel_table[:projekt_id].eq(arel_table[:id]))
      .unscope(:order)
      .arel
      .exists
  end

  def self.consider_underway_setting_exists
    ProjektSetting
      .where(ProjektSetting.arel_table[:projekt_id].eq(arel_table[:id]))
      .where(key: "projekt_feature.general.consider_underway")
      .where.not(value: [nil, ""])
      .unscope(:order)
      .arel
      .exists
  end

  ##################

  scope :visible_for, ->(user) {
    return regular if user&.administrator?
    return regular.activated.where.missing(:individual_group_values) if user.blank?

    projekt_manager = user.projekt_manager

    return regular if projekt_manager&.manage_all_projekts?

    individual_group_value_ids = user.hard_individual_group_value_ids

    unrestricted_or_member =
      group_restricted_predicate.not.or(
        group_membership_predicate(individual_group_value_ids)
      )

    visible =
      activated_predicate
        .and(Arel::Nodes::Grouping.new(unrestricted_or_member))

    if projekt_manager.present?
      visible =
        Arel::Nodes::Grouping.new(visible)
          .or(pm_permission_predicate(projekt_manager, ["manage", "review"]))
    end

    regular.where(visible)
  }

  def self.visible_projekt_ids_for(user)
    Current.visible_projekt_ids ||= {}
    Current.visible_projekt_ids[user&.id] ||= visible_for(user).pluck(:id).to_set
  end

  def self.reset_visible_projekt_ids
    Current.visible_projekt_ids = nil
  end

  def self.activated_predicate
    return arel_table[:activated].eq(true) if USE_SETTING_COLUMNS

    settings = ProjektSetting.arel_table

    settings
      .project(1)
      .where(settings[:projekt_id].eq(arel_table[:id]))
      .where(settings[:key].eq("projekt_feature.main.activate"))
      .where(settings[:value].eq("active"))
      .exists
  end

  # Casts a value in the legacy projekt_settings encoding to its column type.
  def self.cast_legacy_setting_value(value)
    value.to_s.in?(%w[active t true])
  end

  # True when this setting's value is read from its `projekts` column rather
  # than from its `projekt_settings` row.
  def self.setting_read_from_column?(key)
    USE_SETTING_COLUMNS && KEY_TO_COLUMN.key?(key)
  end

  def self.group_restricted_predicate
    restrictions = Arel::Table.new(:individual_group_values_projekts)

    restrictions
      .project(1)
      .where(restrictions[:projekt_id].eq(arel_table[:id]))
      .exists
  end

  def self.group_membership_predicate(individual_group_value_ids)
    return Arel::Nodes::False.new if individual_group_value_ids.blank?

    restrictions = Arel::Table.new(:individual_group_values_projekts)

    restrictions
      .project(1)
      .where(restrictions[:projekt_id].eq(arel_table[:id]))
      .where(restrictions[:individual_group_value_id].in(individual_group_value_ids))
      .exists
  end

  def self.pm_permission_predicate(projekt_manager, permissions)
    assignments = ProjektManagerAssignment.arel_table
    quoted_permissions = permissions.map { |permission| connection.quote(permission) }
    overlaps = Arel::Nodes::InfixOperation.new(
      "&&",
      assignments[:permissions],
      Arel::Nodes::SqlLiteral.new("ARRAY[#{quoted_permissions.join(",")}]::text[]")
    )

    assignments
      .project(1)
      .where(assignments[:projekt_id].eq(arel_table[:id]))
      .where(assignments[:projekt_manager_id].eq(projekt_manager.id))
      .where(overlaps)
      .exists
  end

  scope :for_overview_page_navigation, ->(user) {
    activated
      .visible_for(user)
      .show_in_overview_page_navigation
      .sort_by_order_number
  }

  scope :for_navigation, ->(user) {
    activated
      .visible_for(user)
      .show_in_navigation
      .sort_by_order_number
  }

  ##################

  scope :by_my_posts, ->(my_posts_switch, current_user_id) {
    return unless my_posts_switch

    where(author_id: current_user_id)
  }

  scope :last_week, -> { where("projekts.created_at >= ?", 7.days.ago) }

  scope :sort_by_individual_list, -> {
    individual_list
  }

  scope :with_published_custom_page, -> {
    joins(:page)
      .where(site_customization_pages: { status: "published" })
  }

  def self.includes_children_projekts_with(*sub_relations)
    includes(
      children: [*sub_relations, {children: [*sub_relations]}]
    )
  end

  def self.overview_page
    find_by(
      special_name: "projekt_overview_page",
      special: true
    )
  end

  def self.with_pm_permission_to(permissions, projekt_manager)
    return Projekt.none unless projekt_manager.present?
    return Projekt.none if permissions.blank?
    return all if projekt_manager.manage_all_projekts?

    joins(:projekt_manager_assignments).where(
      "projekt_manager_assignments.projekt_manager_id = ? AND projekt_manager_assignments.permissions && ARRAY[?]::text[]",
      projekt_manager.id,
      Array(permissions)
    )
  end

  def self.selectable_in_selector(controller_name, current_user, resource = nil)
    phase_preload = PHASE_PRELOAD_FOR_CONTROLLER.fetch(controller_name)
    sub_relations = [
      :individual_group_values, :hard_individual_group_values, phase_preload
    ]

    includes(:individual_group_values, phase_preload)
      .includes_children_projekts_with(*sub_relations)
      .includes({ parent: :individual_group_values }, { top_level_projekt: :hard_individual_group_values })
      .select do |projekt|
        (!projekt.hidden_for?(current_user) || projekt.all_parent_projekts.none? { |p| p.hidden_for?(current_user) }) &&
        (projekt.can_assign_resources?(controller_name, current_user, resource) ||
          projekt.all_children_projekts.any? do |p|
            p.can_assign_resources?(controller_name, current_user, resource)
          end
        )
      end
  end

  def self.search(terms)
    pg_search(terms)
  end

  def searchable_values
    { page&.title          => "A",
      title               => "A",
      page&.content       => "C" }
  end

  def projekt_phases_for(resource)
    return debate_phases if resource.is_a?(Debate)
    return proposal_phases if resource.is_a?(Proposal)
    return voting_phases if resource.is_a?(Poll)
    return legislation_phases if resource.is_a?(Legislation::Process)
  end

  def published?
    page&.status == "published"
  end

  def can_assign_resources?(controller_name, user, resource = nil)
    return false if user.nil?
    return true if resource&.respond_to?(:author) && resource.author == user
    return false if !activated? && controller_name != "polls"

    case controller_name
    when "proposals"
      any_phase_selectable?(proposal_phases, user, resource)

    when "debates"
      any_phase_selectable?(debate_phases, user, resource)

    when "polls"
      any_phase_selectable?(voting_phases, user)

    when "processes"
      legislation_phases
        .reject { |phase| phase.legislation_process.present? || !phase.selectable_by?(user) }
        .any?
    end
  end

  def any_phase_selectable?(phases, user, resource = nil)
    phases.to_a.any? { |phase| phase.selectable_by?(user, resource) }
  end

  def top_level?
    order_number.present? && parent.blank?
  end

  def current?(timestamp = Time.zone.today)
    activated? &&
     (total_duration_start.blank? || total_duration_start <= timestamp) &&
     (total_duration_end.blank? || total_duration_end >= timestamp)
  end

  def expired?(timestamp = Time.zone.today)
    activated? &&
      total_duration_end.present? &&
      total_duration_end < timestamp
  end

  # Re-evaluates publish criteria on every save and sets/clears `published_at`
  # accordingly. Always updates if criteria change — no "first visibility wins".
  def sync_published_at
    if meets_publish_criteria?
      self.published_at ||= Time.current
    else
      self.published_at = nil
    end
  end

  # TODO(review): confirm these are the right conditions for a projekt to be
  # considered "published". Adjust the criteria as needed.
  def meets_publish_criteria?
    !special? &&
      activated? &&
      hard_individual_group_values.none? &&
      page&.published?
  end

  # Geo-restricted projekts are left out: most subscribers live outside the
  # affiliated districts and could not take part in what they were notified
  # about. Staff can still send those from the projekt details page.
  def eligible_for_whatsapp_publication_broadcast?
    published_at.present? &&
      geozone_affiliated != "only_geozones"
  end

  # The broadcast carries the projekt link, so a projekt that moved to a new
  # slug is worth announcing again; publishing twice under the same slug is not.
  def whatsapp_broadcast_sent_for_current_slug?
    whatsapp_broadcast_sent_at.present? &&
      whatsapp_broadcast_slug == page&.slug
  end

  # Written with update_columns on purpose: this is bookkeeping, and
  # `content_updated_at` must keep meaning "an editor changed something".
  def mark_whatsapp_broadcast_sent!
    update_columns(
      whatsapp_broadcast_sent_at: Time.current,
      whatsapp_broadcast_slug: page&.slug
    )
  end

  def reset_whatsapp_broadcast!
    update_columns(whatsapp_broadcast_sent_at: nil, whatsapp_broadcast_slug: nil)
  end

  def activated_children
    children.activated
  end

  def calculate_level(counter = 1)
    return counter if parent.blank?

    parent.calculate_level(counter + 1)
  end

  def breadcrumb_trail_ids(breadcrumb_trail_ids = [])
    breadcrumb_trail_ids.unshift(id)

    parent.breadcrumb_trail_ids(breadcrumb_trail_ids) if parent.present?

    breadcrumb_trail_ids
  end

  def breadcrumb_trail(breadcrumb_trail = [])
    breadcrumb_trail.unshift(self)

    parent.breadcrumb_trail(breadcrumb_trail) if parent.present?

    breadcrumb_trail
  end

  def all_parent_ids
    all_parent_projekts.map(&:id)
  end

  def all_parent_projekts
    [parent, top_level_projekt].compact.uniq
  end

  def all_children_ids
    all_children_projekts.map(&:id)
  end

  def all_children_projekts
    children_with_grandchildren =
      children_tree_preloaded? ? children : children.includes(:children)

    children_with_grandchildren.flat_map { |child| [child, *child.children] }
  end

  def children_tree_preloaded?
    children.loaded? &&
      children.all? { |child| child.association(:children).loaded? }
  end

  def has_active_phase?(controller_name)
    case controller_name
    when "proposals"
      proposal_phases.any?(&:current?)
    when "debates"
      debate_phases.any?(&:current?)
    when "polls"
      false
    end
  end

  def top_parent
    return self if parent.blank?

    parent.top_parent
  end

  def siblings
    if parent.present?
      parent.children
    else
      Projekt.top_level
    end
  end

  def order_up
    set_order && return if order_number.blank?
    return if order_number == 1

    swap_order_numbers_up
    ensure_projekt_order_integrity
  end

  def order_down
    set_order && return if order_number.blank?
    return if order_number > siblings.maximum(:order_number)

    swap_order_numbers_down
    ensure_projekt_order_integrity
  end

  def ensure_other_projekts_order_integrity
    Projekt.ensure_order_integrity
  end

  def self.ensure_order_integrity
    all.find_each do |projekt|
      projekt.send(:ensure_projekt_order_integrity)
    end
  end

  def create_default_settings
    existing_keys = projekt_settings.pluck(:key)
    now = Time.current

    setting_rows = ProjektSetting.defaults.except(*existing_keys.map(&:to_sym)).map do |key, value|
      column = KEY_TO_COLUMN[key.to_s]

      {
        projekt_id: id,
        key: key,
        value: column.present? ? legacy_setting_value(column) : value,
        created_at: now,
        updated_at: now
      }
    end
    return if setting_rows.empty?

    ProjektSetting.insert_all(setting_rows)
  end

  def title
    page&.title || name
  end

  def legislation_process
    legislation_processes.order(:updated_at).last
  end

  def overview_page?
    special? && (special_name == OVERVIEW_PAGE_NAME)
  end

  def name
    if overview_page?
      I18n.t("custom.projekts.overview_page.projekt_name")
    else
      super
    end
  end

  def name_for_resource_creation(resource)
    if overview_page?
      resource_name = resource.class.name.downcase

      I18n.t(
        "custom.projekts.overview_page.projekt_name_for_#{resource_name}",
        default: name
      )
    else
      page.title
    end
  end

  def all_ids_in_tree
    all_parent_ids + [id] + all_children_ids
  end

  def all_projekt_labels
    ProjektLabel.where(projekt_id: (all_parent_ids + [id]))
  end

  def all_projekt_labels_in_tree
    ProjektLabel.where(projekt_id: all_ids_in_tree)
  end

  def visible_for?(user = nil)
    Projekt.visible_projekt_ids_for(user).include?(id)
  end

  def hidden_for?(user = nil)
    !visible_for?(user)
  end

  def comments_allowed?(user = nil)
    true
  end

  def section_tracking_section
    "projekts"
  end

  def section_tracking_user
    author
  end

  def current_phases
    projekt_phases.select(&:current?)
  end

  def self.transfer_description_to_page_subtitle
    all.find_each do |p|
      p.translations.each do |t|
        next unless p.page.translations.find_by(locale: t.locale).present?

        p.page.translations.find_by(locale: t.locale).update!(subtitle: t.description)
      end
    end
  end

  def self.transfer_image_to_page
    all.find_each do |p|
      projekt_image = p.image
      next unless projekt_image.present?

      p.page.image = projekt_image
    end
  end

  def projekt_settings_hash
    @projekt_settings_hash ||= projekt_settings.each_with_object({}) do |setting, values|
      values[setting.key] = setting.value
    end
  end

  def activated?
    return self[:activated] if USE_SETTING_COLUMNS

    projekt_settings_hash["projekt_feature.main.activate"].present?
  end

  def feature?(feature)
    key = "projekt_feature.#{feature}"
    return self[KEY_TO_COLUMN[key]] == true if Projekt.setting_read_from_column?(key)

    projekt_settings_hash[key].in?(%w[active t])
  end

  def serialize
    {
      id: id,
      name: name,
      total_duration_start: total_duration_start,
      total_duration_end: total_duration_end,
      preview_code: preview_code,
      show_map: feature?("show_map"),
      show_navigator_in_projekts_page_sidebar: feature?("show_navigator_in_projekts_page_sidebar"),
      show_notification_subscription_toggler: feature?("show_notification_subscription_toggler"),
      show_phases_in_projekt_page_sidebar: feature?("show_phases_in_projekt_page_sidebar"),
      projekt_page_sharing: feature?("projekt_page_sharing"),
      page: {
        title: page.title,
        slug: page.slug,
        subtitle: page.subtitle,
        content: page.content
      }
    }
  end

  def generate_preview_code_if_nedded!
    return if preview_code.present?

    regenerate_preview_code
    save!
  end

  def gen_projekt_url(url_params = {})
    uri = URI.parse(page.url)

    uri_params = URI.decode_www_form(uri.query || "")
    uri_params += url_params.to_a

    uri.query = URI.encode_www_form(uri_params)
    uri.to_s
  end

  def preview_code_valid?(code)
    preview_code.present? && preview_code == code
  end

  def acceptable_to_be_exported_for_global_overview?
    !special &&
      page&.published? &&
      activated? &&
      feature?("general.show_in_overview_page")
  end

  def any_phase_subscribers_ids
    User.joins(:projekt_phase_subscriptions)
      .where(projekt_phase_subscriptions: { projekt_phase_id: projekt_phases.ids })
      .ids.uniq
  end

  def page_content
    if new_content_block_mode?
      # join, never reduce(:concat): concat mutates the receiver, so reducing
      # over the bodies appended the whole page into the first content block's
      # in-memory body and left the record dirty, one save away from
      # overwriting it.
      content_blocks_content = content_blocks.map(&:body).join

      ActionView::Base.full_sanitizer.sanitize(content_blocks_content, tags: ["h1", "h2" "h3", "h4", "ul", "li"])
    else
      page.content
    end
  end

  def content_blocks_body
    content_blocks
      .sort_by(&:position)
      .map(&:body)
      .compact_blank
      .join("\n")
  end

  def perform_sync_update_for_global_overview
    if should_be_exported_for_global_overview?
      if hidden_at.present?
        sync_destroy_for_global_overview
      else
        Projekts::OverviewProjektUpdatedJob.perform_later(self)
      end
    end
  end

  def sync_for_global_overview_from_page_changes(page_saved_changes)
    changed_set = page_saved_changes.except("created_at", "updated_at")
    return if changed_set.empty?

    perform_sync_update_for_global_overview
  end

  private

    # Rides on `published_at` so the trigger stays whatever
    # `meets_publish_criteria?` says publishing is. Enqueued after commit so
    # the job never reads a projekt the transaction still rolls back.
    #
    # Delayed by PUBLICATION_BROADCAST_DELAY (20 minutes) rather than sent at
    # once: publishing is usually followed by a few minutes of last-minute
    # edits to the title, image and content blocks, and the message carries
    # the title plus a link people open immediately. The delay lets those
    # edits land first. Note it is an offset, not a cancel window —
    # deactivating the projekt again within it does not stop the queued job.
    def broadcast_publication_on_whatsapp
      return if !saved_change_to_published_at?
      return if !eligible_for_whatsapp_publication_broadcast?
      return if !::Whatsapp.auto_broadcast_new_projekts?

      ::Whatsapp::BroadcastProjektJob
        .set(wait: ::Whatsapp::PUBLICATION_BROADCAST_DELAY)
        .perform_later(id)
    end

    def create_corresponding_page
      create_page(
        title: name,
        slug: generate_page_slug(name),
        status: "published",
        content: ""
      )
    end

    def generate_page_slug(title)
      clean_slug = title.downcase.gsub("ä", "ae").gsub("ö", "oe").gsub("ü", "ue").gsub("ß", "ss")
        .gsub(/[^a-z0-9\s]/, "").gsub(/\s+/, "-")
      pages_with_similar_slugs = SiteCustomization::Page.where("slug ~ ?", "^#{clean_slug}(-[0-9]+$|$)")
        .where.not(id: page&.id)
        .order(id: :asc)

      if pages_with_similar_slugs.any? && pages_with_similar_slugs.last.slug.match?(/-\d+$/)
        clean_slug + "-" + (pages_with_similar_slugs.last.slug.split("-")[-1].to_i + 1).to_s
      elsif pages_with_similar_slugs.any?
        clean_slug + "-2"
      else
        clean_slug
      end
    end

    def set_order
      return unless order_number.blank?

      if siblings.with_order_number.any? &&
          siblings.with_order_number.pluck(:order_number).first == 1 &&
          siblings.with_order_number.pluck(:order_number).each_cons(2).all? { |a, b| b == a + 1 }
        ordered_siblings_count = siblings.with_order_number.last.order_number
        update!(order_number: ordered_siblings_count + 1)
      elsif siblings.with_order_number.any?
        update!(order_number: 0)
        ensure_projekt_order_integrity
      else
        update!(order_number: 1)
      end
    end

    def swap_order_numbers_up
      if siblings.with_order_number.where("order_number < ?", order_number).any?
        preceding_sibling_order_number = siblings.with_order_number.where("order_number < ?", order_number)
          .last.order_number
        preceding_sibling = siblings.find_by(order_number: preceding_sibling_order_number)

        preceding_sibling.update!(order_number: order_number)
        update!(order_number: preceding_sibling_order_number)
      end
    end

    def swap_order_numbers_down
      if siblings.with_order_number.where("order_number > ?", order_number).any?
        following_sibling_order_number = siblings.with_order_number.where("order_number > ?", order_number)
          .first.order_number
        following_sibling = siblings.find_by(order_number: following_sibling_order_number)

        following_sibling.update!(order_number: order_number)
        update!(order_number: following_sibling_order_number)
      end
    end

    def ensure_projekt_order_integrity
      unless siblings.with_order_number.pluck(:order_number).first == 1 &&
          siblings.with_order_number.pluck(:order_number).each_cons(2).all? { |a, b| b == a + 1 }
        new_order = 1
        siblings.with_order_number.each do |projekt|
          projekt.update_column(:order_number, new_order)
          new_order += 1
        end
      end
    end

    def copy_map_settings
      return if map_location.present?

      create_map_location

      (parent&.map_layers.presence || MapLayer.default).each do |map_layer|
        map_layers << map_layer.dup
      end
    end

    def touch_updated_at(geozone)
      Projekt.reset_visible_projekt_ids

      touch if persisted?
    end

    def reset_visible_projekt_ids_cache
      Projekt.reset_visible_projekt_ids
    end

    def recalculate_subtree_levels
      update_column("level", calculate_level)

      pending_projekts = [self]

      while pending_projekts.any?
        current_projekt = pending_projekts.shift

        current_projekt.children.each do |child|
          child.update_column("level", current_projekt.level + 1)
          pending_projekts << child
        end
      end
    end

    def assign_author_as_manager
      projekt_manager = author&.projekt_manager
      return if projekt_manager.blank?
      return if projekt_manager.manage_all_projekts?

      assignment = projekt_manager_assignments.find_or_initialize_by(projekt_manager: projekt_manager)
      assignment.permissions |= ProjektManagerAssignment::ACCEPTABLE_PERMISSIONS
      assignment.save!
    end

    def assign_top_level_projekt_from_parent
      return unless parent_id_changed?

      if parent&.parent_id.present?
        self.top_level_projekt_id = parent.parent_id
      end
    end

    def initialize_content_updated_at
      self.content_updated_at = Time.current
    end

    def bump_content_updated_at
      relevant_changes =
        changes_to_save.except("order_number", "updated_at", "content_updated_at")
      return if relevant_changes.blank?

      self.content_updated_at = Time.current
    end

    def legacy_setting_value(column)
      self[column] ? "active" : ""
    end

    # The projekt_settings row stays the value every other reader sees (the
    # public API, the /admin UI), so a column write has to update it too.
    def mirror_setting_columns_to_legacy_rows
      changed_keys = KEY_TO_COLUMN.select do |_key, column|
        saved_change_to_attribute?(column)
      end
      return if changed_keys.empty?

      now = Time.current
      existing_keys = ProjektSetting.where(projekt_id: id, key: changed_keys.keys).pluck(:key)

      changed_keys.slice(*existing_keys).each do |key, column|
        ProjektSetting
          .where(projekt_id: id, key: key)
          .update_all(value: legacy_setting_value(column), updated_at: now)
      end

      missing_rows = changed_keys.except(*existing_keys).map do |key, column|
        {
          projekt_id: id,
          key: key,
          value: legacy_setting_value(column),
          created_at: now,
          updated_at: now
        }
      end

      ProjektSetting.insert_all(missing_rows) if missing_rows.present?
    end

    def sync_children_activated
      all_children_projekts.each do |child|
        child.update!(activated: activated)
      end
    end

    def sync_for_global_overview_if_changed
      # Ignore order number update change
      changed_set = previous_changes.except("created_at", "updated_at")

      if changed_set["order_number"].present? && changed_set.size == 1
        return
      end

      perform_sync_update_for_global_overview
    end

    def sync_destroy_for_global_overview
      return unless on_dt_global_overview?

      Projekts::OverviewProjektDestroyedJob.perform_later(id)
      update_column(:on_dt_global_overview, false) unless destroyed?
    end
end
