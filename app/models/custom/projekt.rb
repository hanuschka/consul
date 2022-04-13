class Projekt < ApplicationRecord
  include Milestoneable
  acts_as_paranoid column: :hidden_at
  include ActsAsParanoidAliases
  include Mappable
  include ActiveModel::Dirty
  include SDG::Relatable
  include Taggable
  include Imageable

  translates :description
  include Globalizable

  has_many :children, -> { order(order_number: :asc) }, class_name: 'Projekt', foreign_key: 'parent_id'
  belongs_to :parent, class_name: 'Projekt', optional: true

  has_many :debates, dependent: :nullify
  has_many :proposals, dependent: :nullify
  has_many :polls, dependent: :nullify
  has_one :budget, dependent: :nullify
  has_many :projekt_events, dependent: :nullify

  has_one :page, class_name: "SiteCustomization::Page", dependent: :destroy

  has_many :projekt_phases, dependent: :destroy
  has_one :debate_phase, class_name: 'ProjektPhase::DebatePhase'
  has_one :proposal_phase, class_name: 'ProjektPhase::ProposalPhase'
  has_one :budget_phase, class_name: 'ProjektPhase::BudgetPhase'
  has_one :comment_phase, class_name: 'ProjektPhase::CommentPhase'
  has_one :voting_phase, class_name: 'ProjektPhase::VotingPhase'
  has_one :milestone_phase, class_name: 'ProjektPhase::MilestonePhase'
  has_one :projekt_notification_phase, class_name: 'ProjektPhase::ProjektNotificationPhase'
  has_one :newsfeed_phase, class_name: 'ProjektPhase::NewsfeedPhase'
  has_one :event_phase, class_name: 'ProjektPhase::EventPhase'
  has_many :geozone_restrictions, through: :projekt_phases
  has_and_belongs_to_many :geozone_affiliations, through: :geozones_projekts, class_name: 'Geozone'

  has_many :projekt_settings, dependent: :destroy
  has_many :projekt_notifications, dependent: :destroy

  has_many :comments, as: :commentable, inverse_of: :commentable, dependent: :destroy
  belongs_to :author, -> { with_hidden }, class_name: "User", inverse_of: :projekts

  accepts_nested_attributes_for :debate_phase, :proposal_phase, :budget_phase, :voting_phase, :comment_phase, :milestone_phase, :projekt_notifications, :projekt_events, :event_phase

  before_validation :set_default_color
  around_update :update_page
  after_create :create_corresponding_page, :set_order, :create_projekt_phases, :create_default_settings, :create_map_location
  after_save do
    Projekt.all.each { |projekt| projekt.update_column('level', projekt.calculate_level) }
    Projekt.all.each { |projekt| projekt.update_selectable_in_sidebar_selectors }
  end
  after_destroy :ensure_projekt_order_integrity

  validates :color, format: { with: /\A#[\d, a-f, A-F]{6}\Z/ }
  validates :name, presence: true

  scope :with_order_number, -> { where.not(order_number: nil).order(order_number: :asc) }
  scope :top_level, -> { with_order_number.
                         where(parent: nil) }
  scope :activated, -> { joins( 'INNER JOIN projekt_settings act ON projekts.id = act.projekt_id' ).
                         where( 'act.key': 'projekt_feature.main.activate', 'act.value': 'active' ) }

  scope :current, ->(timestamp = Date.today) { activated.
                                               where( "total_duration_start IS NULL OR total_duration_start <= ?", Date.today ).
                                               where( "total_duration_end IS NULL OR total_duration_end >= ?", Date.today) }
  scope :expired, ->(timestamp = Date.today) { activated.
                                               where( "total_duration_end < ?", Date.today) }

  scope :visible_in_menu, -> { joins( 'INNER JOIN projekt_settings vim ON projekts.id = vim.projekt_id').
                               where( 'vim.key': 'projekt_feature.general.show_in_navigation', 'vim.value': 'active' ) }

  scope :with_active_feature, ->(projekt_feature_key) { joins( 'INNER JOIN projekt_settings waf ON projekts.id = waf.projekt_id').
                                                        where( 'waf.key': "projekt_feature.#{projekt_feature_key}", 'waf.value': 'active' ) }

  scope :top_level_navigation, -> { top_level.visible_in_menu }

  scope :top_level_sidebar_current, ->(controller_name) { top_level.selectable_in_sidebar_current(controller_name) }
  scope :top_level_sidebar_expired, ->(controller_name) { top_level.selectable_in_sidebar_expired(controller_name) }

  scope :by_my_posts, -> (my_posts_switch, current_user_id) {
    return unless my_posts_switch

    where(author_id: current_user_id)
  }

  class << self
    def selectable_in_selector(controller_name, current_user)
      select { |projekt| projekt.all_children_projekts.unshift(projekt).any? { |p| p.selectable?(controller_name, current_user) } }
    end

    def selectable_in_sidebar_current(controller_name)
      select { |projekt| projekt.selectable_in_sidebar_selector["#{controller_name}_current"] }
    end

    def selectable_in_sidebar_expired(controller_name)
      select { |projekt| projekt.selectable_in_sidebar_selector["#{controller_name}_expired"] }
    end
  end

  def regular_projekt_phases
    projekt_phases.
      where.not(type: ['ProjektPhase::MilestonePhase', 'ProjektPhase::ProjektNotificationPhase', 'ProjektPhase::NewsfeedPhase' ])
  end

  def update_page
    update_corresponding_page if self.name_changed?
    yield
  end

  def selectable?(controller_name, user)
    return true if controller_name == 'polls'
    return false if user.nil?
    return false if selectable_by_admins_only? && user.administrator.blank?

    if controller_name == 'proposals'
      proposal_phase.selectable_by?(user)
    elsif controller_name == 'debates'
      debate_phase.selectable_by?(user)
    end
  end

  def top_level?
    order_number.present? && parent.blank?
  end

  def activated?
    projekt_settings.
      find_by( projekt_settings: { key: "projekt_feature.main.activate" } ).
      value.
      present?
  end

  def current?(timestamp = Date.today)
    activated? &&
     ( total_duration_start.blank? || total_duration_start <= timestamp) &&
     ( total_duration_end.blank? || total_duration_end >= timestamp )
  end

  def expired?(timestamp = Date.today)
    activated? &&
      total_duration_end.present? &&
      total_duration_end < timestamp
  end

  def selectable_by_admins_only?
    projekt_settings.
      find_by( projekt_settings: { key: "projekt_feature.general.only_admins_create_debates_proposals" } ).
      value.
      present?
  end

  def activated_children
    children.activated
  end

  def children_with_active_feature(projekt_feature_key)
    children.merge(Projekt.with_active_feature(projekt_feature_key))
  end

  def comments_allowed?(current_user)
    current_user.level_two_or_three_verified? &&
      current? &&
      comment_phase.current?
  end

  def calculate_level(counter = 1)
    return counter if self.parent.blank?
    self.parent.calculate_level(counter+1)
  end

  def breadcrumb_trail_ids(breadcrumb_trail_ids = [])
    breadcrumb_trail_ids.unshift(self.id)

    parent.breadcrumb_trail_ids(breadcrumb_trail_ids) if parent.present?

    breadcrumb_trail_ids
  end

  def all_parent_ids(all_parent_ids = [])
    if self.parent.present?
      all_parent_ids.push(parent.id)
      parent.all_parent_ids(all_parent_ids)
    end

    all_parent_ids
  end

  def all_children_ids(all_children_ids = [])
    if self.children.any?
      self.children.each do |child|
        all_children_ids.push(child.id)
        child.all_children_ids(all_children_ids)
      end
    end

    all_children_ids
  end

  def all_children_projekts(all_children_projekts = [])
    if self.children.any?
      self.children.each do |child|
        all_children_projekts.push(child)
        child.all_children_projekts(all_children_projekts)
      end
    end

    all_children_projekts
  end

  def selectable_tree_ids(controller_name, filter)
    if filter == 'active'
      all_children_projekts.unshift(self) & Projekt.selectable_in_sidebar_current(controller_name)
    else
      all_children_projekts.unshift(self) & Projekt.selectable_in_sidebar_expired(controller_name)
    end
  end

  def has_active_phase?(controller_name)
    case controller_name
    when 'proposals'
      proposal_phase.current?
    when 'debates'
      debate_phase.current?
    when 'polls'
      false
    end
  end

  def top_parent
    return self if self.parent.blank?
    self.parent.top_parent
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

  def self.ensure_order_integrity
    all.each do |projekt|
      projekt.send(:ensure_projekt_order_integrity)
    end
  end

  def create_default_settings
    ProjektSetting.defaults.each do |name, value|
      unless ProjektSetting.find_by(key: name, projekt_id: self.id)
        ProjektSetting.create(key: name, value: value, projekt_id: self.id)
      end
    end
  end

  def self.ensure_projekt_phases
    all.each do |projekt|
      projekt.debate_phase = ProjektPhase::DebatePhase.create unless projekt.debate_phase
      projekt.proposal_phase = ProjektPhase::ProposalPhase.create unless projekt.proposal_phase
      projekt.budget_phase = ProjektPhase::BudgetPhase.create unless projekt.budget_phase
      projekt.comment_phase = ProjektPhase::CommentPhase.create unless projekt.comment_phase
      projekt.voting_phase = ProjektPhase::VotingPhase.create unless projekt.voting_phase
      projekt.milestone_phase = ProjektPhase::MilestonePhase.create unless projekt.milestone_phase
      projekt.projekt_notification_phase = ProjektPhase::ProjektNotificationPhase.create unless projekt.projekt_notification_phase
      projekt.newsfeed_phase = ProjektPhase::NewsfeedPhase.create unless projekt.newsfeed_phase
      projekt.event_phase = ProjektPhase::EventPhase.create unless projekt.event_phase
    end
  end

  def update_selectable_in_sidebar_selectors
    controller_names = ['proposals', 'debates', 'polls', 'projekt_events']

    controller_names.each do |controller_name|
      set_selectable_in_sidebar_selector(controller_name, 'current')
      set_selectable_in_sidebar_selector(controller_name, 'expired')
    end
  end

  def set_selectable_in_sidebar_selector(controller_name, group)
    selectable_in_sidebar_selector_value = selectable_in_sidebar_selector

    if group == 'current'
      selectable_in_sidebar_selector_value["#{controller_name}_#{group}"] = all_children_projekts.unshift(self).any? { |p| p.current? && ( p.send(controller_name).any? || p.has_active_phase?(controller_name) ) }
    elsif group == 'expired'
      selectable_in_sidebar_selector_value["#{controller_name}_#{group}"] = all_children_projekts.unshift(self).any? { |p| p.expired? && p.send(controller_name).any? }
    end

    self.update_column('selectable_in_sidebar_selector', selectable_in_sidebar_selector_value)
  end

  def title
    name
  end

  private

  def create_corresponding_page
    page = SiteCustomization::Page.new(title: self.name, slug: form_page_slug, projekt: self)

    if page.save
      self.page = page
    end
  end

  def update_corresponding_page
    page.update(title: name, slug: form_page_slug)
  end

  def form_page_slug
    page_title = self.name
    clean_slug = self.name.downcase.gsub('ä', 'ae').gsub('ö', 'oe').gsub('ü', 'ue').gsub('ß', 'ss').gsub(/[^a-z0-9\s]/, '').gsub(/\s+/, '-')
    pages_with_similar_slugs = SiteCustomization::Page.where("slug ~ ?", "^#{clean_slug}(-[0-9]+$|$)").order(id: :asc)

    if pages_with_similar_slugs.any? && pages_with_similar_slugs.last.slug.match?(/-\d+$/)
      page_slug = clean_slug + '-' + (pages_with_similar_slugs.last.slug.split('-')[-1].to_i + 1).to_s
    elsif pages_with_similar_slugs.any?
      page_slug = clean_slug + '-2'
    else
      page_slug = clean_slug
    end
  end

  def set_order
    return unless order_number.blank?

    if self.siblings.with_order_number.any? && siblings.with_order_number.pluck(:order_number).first == 1 && siblings.with_order_number.pluck(:order_number).each_cons(2).all? { |a, b| b == a + 1 }
      ordered_siblings_count = self.siblings.with_order_number.last.order_number
      self.update(order_number: ordered_siblings_count + 1)
    elsif self.siblings.with_order_number.any?
      self.update(order_number: 0)
      ensure_projekt_order_integrity
    else
      self.update(order_number: 1)
    end
  end

  def create_projekt_phases
    self.debate_phase = ProjektPhase::DebatePhase.create
    self.proposal_phase = ProjektPhase::ProposalPhase.create
    self.budget_phase = ProjektPhase::BudgetPhase.create
    self.comment_phase = ProjektPhase::CommentPhase.create
    self.voting_phase = ProjektPhase::VotingPhase.create
    self.milestone_phase = ProjektPhase::MilestonePhase.create
    self.projekt_notification_phase = ProjektPhase::ProjektNotificationPhase.create
    self.newsfeed_phase = ProjektPhase::NewsfeedPhase.create
    self.event_phase = ProjektPhase::EventPhase.create
  end

  def swap_order_numbers_up
    if siblings.with_order_number.where("order_number < ?", order_number).any?
      preceding_sibling_order_number = siblings.with_order_number.where("order_number < ?", order_number).last.order_number
      preceding_sibling = siblings.find_by(order_number: preceding_sibling_order_number)

      preceding_sibling.update(order_number: order_number)
      self.update(order_number: preceding_sibling_order_number)
    end
  end

  def swap_order_numbers_down
    if siblings.with_order_number.where("order_number > ?", order_number).any?
      following_sibling_order_number = siblings.with_order_number.where("order_number > ?", order_number).first.order_number
      following_sibling = siblings.find_by(order_number: following_sibling_order_number)

      following_sibling.update(order_number: order_number)
      self.update(order_number: following_sibling_order_number)
    end
  end

  def ensure_projekt_order_integrity
    unless siblings.with_order_number.pluck(:order_number).first == 1 && siblings.with_order_number.pluck(:order_number).each_cons(2).all? { |a, b| b == a + 1 }
      new_order = 1
      siblings.with_order_number.each do |projekt|
        projekt.update(order_number: new_order)
        new_order += 1
      end
    end
  end

  def create_map_location
    unless map_location.present?
      MapLocation.create(
        latitude: Setting['map.latitude'],
        longitude: Setting['map.longitude'],
        zoom: Setting['map.zoom'],
        projekt_id: self.id
      )
    end
  end

  def set_default_color
    self.color ||= "#004a83"
  end
end
