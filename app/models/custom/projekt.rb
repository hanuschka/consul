class Projekt < ApplicationRecord
  OVERVIEW_PAGE_NAME = "projekt_overview_page".freeze
  INDEX_FILTERS = %w[
    index_order_underway index_order_all
    index_order_ongoing index_order_upcoming
    index_order_expired index_order_individual_list
  ].freeze

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

  after_save do
    if parent_id_previously_changed?
      Projekt.all.find_each { |projekt| projekt.update_column("level", projekt.calculate_level) }
    end
  end

  before_save :assign_top_level_projekt_from_parent
  before_save :sync_published_at

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

  scope :activated, -> {
    joins("INNER JOIN projekt_settings act ON projekts.id = act.projekt_id")
      .where("act.key": "projekt_feature.main.activate", "act.value": "active")
  }

  scope :not_activated, -> {
    joins("INNER JOIN projekt_settings nact ON projekts.id = nact.projekt_id")
      .where("nact.key": "projekt_feature.main.activate", "nact.value": [nil, ""])
  }

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
      .joins("INNER JOIN projekt_settings siil ON projekts.id = siil.projekt_id")
      .where("siil.key": "projekt_feature.general.show_in_individual_list", "siil.value": "active")
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

  scope :not_in_individual_list, -> {
    joins("INNER JOIN projekt_settings siil ON projekts.id = siil.projekt_id")
      .where("siil.key": "projekt_feature.general.show_in_individual_list", "siil.value": [nil, ""])
  }

  scope :show_in_overview_page, -> {
    joins("INNER JOIN projekt_settings siop ON projekts.id = siop.projekt_id")
      .where("siop.key": "projekt_feature.general.show_in_overview_page", "siop.value": "active")
  }

  scope :show_in_homepage, -> {
    joins("INNER JOIN projekt_settings sihp ON projekts.id = sihp.projekt_id")
      .where("sihp.key": "projekt_feature.general.show_in_homepage", "sihp.value": "active")
  }

  ##################

  scope :visible_for, ->(user) {
    return regular if user&.administrator?

    if user.present?
      user_hard_group_value_ids = user.individual_group_values
        .joins(:individual_group)
        .where(individual_groups: { kind: "hard" })
        .select(:id)

      excluded_projekt_ids = Projekt.joins(:individual_group_values)
                                    .where.not(id: Projekt
                                      .joins(:individual_group_values)
                                      .where(individual_group_values: { id: user_hard_group_value_ids })
                                    )
                                    .select(:id)

      permitted_projekt_ids = Projekt.with_pm_permission_to(["manage", "review"], user.projekt_manager).select(:id)

      arel = Projekt.arel_table

      regular.where(
        arel[:id].in(
          Projekt.activated.where.not(id: excluded_projekt_ids).select(:id).arel
        ).or(
          arel[:id].in(permitted_projekt_ids.arel)
        )
      )
    else
      regular.activated
        .where.not(id: Projekt.joins(:individual_group_values).select(:id))
    end
  }

  scope :for_overview_page_navigation, ->(user) {
    activated
      .visible_for(user)
      .joins(:projekt_settings)
      .where(projekt_settings: { key: "projekt_feature.general.show_in_overview_page_navigation", value: "active" })
      .sort_by_order_number
  }

  scope :for_navigation, ->(user) {
    activated
      .visible_for(user)
      .joins("INNER JOIN projekt_settings vim ON projekts.id = vim.projekt_id")
      .where("vim.key": "projekt_feature.general.show_in_navigation", "vim.value": "active")
      .sort_by_order_number
  }


  ##################

  scope :show_in_sidebar_filter, -> {
    joins("INNER JOIN projekt_settings show_in_sidebar_filter_settings ON projekts.id = show_in_sidebar_filter_settings.projekt_id")
      .where("show_in_sidebar_filter_settings.key": "projekt_feature.general.show_in_sidebar_filter", "show_in_sidebar_filter_settings.value": "active")
  }

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
    includes(:individual_group_values, :projekt_settings, { proposal_phases: [:individual_group_values, :settings] })
      .includes_children_projekts_with(:individual_group_values, :proposal_phases, :individual_group_values, :projekt_settings, :hard_individual_group_values)
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
    return false unless activated? || controller_name == "polls"

    if controller_name == "proposals"
      proposal_phases.any_selectable?(user, resource)

    elsif controller_name == "debates"
      debate_phases.any_selectable?(user, resource)

    elsif controller_name == "polls"
      voting_phases.any_selectable?(user)

    elsif controller_name == "processes"
      legislation_phases
        .reject { |lp| lp.legislation_process.present? || !lp.selectable_by?(user) }
        .any?
    end
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

  # def activated?
  #   projekt_settings.
  #     find_by(projekt_settings: { key: "projekt_feature.main.activate" }).
  #     value.
  #     present?
  # end
  def projekt_settings_hash
    @projekt_settings ||= projekt_settings.reload.pluck(:key, :value).to_h
  end

  def activated?
    projekt_settings_hash["projekt_feature.main.activate"].present?
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

  def all_parent_ids
    all_parent_projekts.map(&:id)
  end

  def all_parent_projekts
    Projekt.where(id: [parent_id, top_level_projekt_id]).compact
  end

  def all_children_ids
    all_children_projekts.map(&:id)
  end

  def all_children_projekts
    children_with_preloaded_grandchildren = children.includes(:children)
    children_with_preloaded_grandchildren.flat_map { |child| [child, *child.children] }.compact
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
    ProjektSetting.defaults.each do |name, value|
      unless ProjektSetting.find_by(key: name, projekt_id: id)
        ProjektSetting.create!(key: name, value: value, projekt_id: id)
      end
    end
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
    Projekt.visible_for(user).where(id: id).exists?
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

  def vc_map_enabled?
    projekt_settings.find_by(key: "projekt_feature.general.vc_map_enabled")&.enabled?
  end

  def self.available_filters(all_projekts)
    return [] if all_projekts.blank?

    projekts_count_hash = {}
    INDEX_FILTERS.each do |order|
      projekts_count_hash[order] = all_projekts.send(order).count
    end

    projekts_count_hash.select { |_, value| value > 0 }.keys
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

  def feature?(feature)
    setting = projekt_settings.find { |setting| setting.key == "projekt_feature.#{feature}"}
    (setting && (setting.value == 'active' || setting.value == 't'  )) ? true : false
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

  def update_bool_setting(key, value)
    value_to_set =
      if (value == "true") || value == true || value == "active"
        "active"
      else
        nil
      end

    find_setting(key)&.update(value: value_to_set)
  end

  def find_setting(key)
    projekt_settings.find { |setting| setting.key == key}
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
      projekt_settings.find_by(key: "projekt_feature.main.activate")&.value == "active" &&
      projekt_settings.find_by(key: "projekt_feature.general.show_in_overview_page")&.value == "active"
  end

  def any_phase_subscribers_ids
    User.joins(:projekt_phase_subscriptions)
      .where(projekt_phase_subscriptions: { projekt_phase_id: projekt_phases.ids })
      .ids.uniq
  end

  def page_content
    if new_content_block_mode?
      content_blocks_content =
        content_blocks
          .map(&:body)
          .reduce(&:concat)

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
      touch if persisted?
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
