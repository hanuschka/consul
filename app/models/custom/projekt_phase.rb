class ProjektPhase < ApplicationRecord
  include Mappable
  include Milestoneable
  acts_as_paranoid column: :hidden_at
  include ActsAsParanoidAliases
  include Notifiable
  include StatsVersionable

  after_create :add_default_settings

  # Ordered list of projekt phases
  PROJEKT_PHASES_TYPES = [
    "ProjektPhase::CommentPhase",
    "ProjektPhase::ProposalPhase",
    "ProjektPhase::PointOfInterestPhase",
    "ProjektPhase::QuestionPhase",
    "ProjektPhase::VotingPhase",
    "ProjektPhase::IframePhase",
    "ProjektPhase::BudgetPhase",
    "ProjektPhase::LegislationPhase",
    "ProjektPhase::FormularPhase",
    "ProjektPhase::EventPhase",
    "ProjektPhase::MilestonePhase",
    "ProjektPhase::ProjektNotificationPhase",
    "ProjektPhase::LivestreamPhase",
    "ProjektPhase::ArgumentPhase",
    "ProjektPhase::NewsfeedPhase"
  ].freeze

  SPECIAL_PROJEKT_PHASES = [
    "ProjektPhase::LivestreamPhase",
    "ProjektPhase::MilestonePhase",
    "ProjektPhase::ProjektNotificationPhase",
    "ProjektPhase::EventPhase",
    "ProjektPhase::ArgumentPhase",
    "ProjektPhase::NewsfeedPhase"
  ].freeze

  delegate :icon, :author, :author_id, to: :projekt

  translates :phase_tab_name, touch: true
  translates :cta_button_name, touch: true
  translates :welcome_text_in_show, touch: true
  translates :resource_form_intro, touch: true
  translates :labels_name, touch: true
  translates :sentiments_name, touch: true
  translates :description, touch: true
  translates :comment_form_title, touch: true
  translates :comment_form_button, touch: true
  translates :resource_form_title, touch: true
  translates :resource_form_title_placeholder, touch: true
  translates :resource_form_description_placeholder, touch: true
  translates :support_button_text, touch: true
  include Globalizable

  belongs_to :projekt, touch: true
  has_many :projekt_settings, through: :projekt
  has_many :settings, class_name: "ProjektPhaseSetting", foreign_key: :projekt_phase_id,
    dependent: :destroy, inverse_of: :projekt_phase
  has_many :projekt_labels, dependent: :destroy
  has_many :sentiments, dependent: :destroy

  has_many :age_range_projekt_phases_for_stats, -> {
 where("used_for" => "stats") }, class_name: "AgeRangeProjektPhase", dependent: :destroy
  has_many :age_ranges_for_stats, through: :age_range_projekt_phases_for_stats, source: :age_range

  belongs_to :age_restriction, class_name: "AgeRange", foreign_key: :age_range_id,
                               optional: true, inverse_of: :age_restricted_projekt_phases

  has_many :projekt_phase_geozones, dependent: :destroy
  has_many :geozone_affiliations, through: :projekt
  has_many :registered_address_district_affiliations, through: :projekt
  has_many :geozone_restrictions, through: :projekt_phase_geozones, source: :geozone,
           after_add: :touch_updated_at, after_remove: :touch_updated_at

  has_and_belongs_to_many :individual_group_values,
    after_add: :touch_updated_at, after_remove: :touch_updated_at

  has_many :registered_address_district_projekt_phase, dependent: :destroy
  has_many :registered_address_districts, through: :registered_address_district_projekt_phase

  has_many :registered_address_street_projekt_phase, dependent: :destroy
  has_many :registered_address_streets, through: :registered_address_street_projekt_phase

  has_many :subscriptions, class_name: "ProjektPhaseSubscription", dependent: :destroy
  has_many :subscribers, through: :subscriptions, source: :user

  has_many :map_layers, as: :mappable, dependent: :destroy
  has_many :comments, as: :commentable, inverse_of: :commentable, dependent: :destroy
  has_many :stat_questions,
           class_name: "ProjektPhaseStatQuestion",
           foreign_key: :projekt_phase_id,
           dependent: :destroy

  has_many :officing_manager_assignments, dependent: :destroy
  has_many :officing_managers, through: :officing_manager_assignments
  has_many :user_resource_criteria, class_name: "UserResourceCriteria", dependent: :destroy

  accepts_nested_attributes_for :settings

  enum user_status: {
    guest: 0,
    registered: 1,
    verified: 2
  }

  enum ai_stats_refresh_status: {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed"
  }, _prefix: :ai_stats_refresh

  validates :projekt, presence: true
  validate :type_must_be_valid

  def self.find_sti_class(type_name)
    if PROJEKT_PHASES_TYPES.include?(type_name)
      super
    else
      self
    end
  rescue NameError
    self
  end

  default_scope { order(:given_order, :id) }

  scope :regular_phases, -> { where.not(type: SPECIAL_PROJEKT_PHASES) }
  scope :special_phases, -> { where(type: SPECIAL_PROJEKT_PHASES) }

  scope :frontend_visible, -> { where(frontend_visibility: true) }

  scope :active, -> {
    where(active: true).where.not(type: "ProjektPhase::DebatePhase")
  }

  scope :current, ->(timestamp = Time.zone.today) {
    active
      .where("start_date IS NULL OR start_date <= ?", timestamp)
      .where("end_date IS NULL OR end_date >= ?", timestamp)
  }

  scope :has_resources, -> {
    ids_with_resources = joins(:resources).select(:id)
    where(id: ids_with_resources)
  }

  scope :sorted, -> { order(:given_order) }

  scope :with_feature, ->(feature_key, state = "on") {
    joins(:settings)
      .where("projekt_phase_settings.key = ?", "feature.#{feature_key}")
      .where(projekt_phase_settings: { value: (state == "on" ? "active" : [nil, ""]) })
  }

  def self.order_phases(ordered_array)
    ordered_array.each_with_index do |phase_id, order|
      find(phase_id).update_column(:given_order, (order + 1))
    end
  end

  def self.model_name
    mname = super
    mname.instance_variable_set(:@route_key, "projekt_phases")
    mname.instance_variable_set(:@singular_route_key, "projekt_phase")
    mname
  end

  def self.any_selectable?(user, resource = nil)
    any? { |phase| phase.selectable_by?(user, resource) }
  end

  def selectable_by?(user, resource = nil)
    # return true if resource&.respond_to?(:author) && resource.author == user
    return false if selectable_by_admins_only? && !user.has_pm_permission_to?("manage", projekt)

    permission_problem(user).blank?
  end

  def votable_by?(user, resource = nil)
    permission_problem(user).blank?
  end

  def comments_allowed?(user, resource = nil)
    feature?("resource.show_comments") &&
      permission_problem(user).blank?
  end

  def not_active?
    !active?
  end

  def expired?
    end_date.present? && end_date < Time.zone.today
  end

  def current?(timestamp = Time.zone.today)
    self.class.current(timestamp).where(id:).exists?
  end

  def not_current?
    !current?
  end

  def permission_problem(user, location: nil)
    @permission_problem_cache ||= {}
    cache_key = "#{user&.id}_#{location}"

    return @permission_problem_cache[cache_key] if @permission_problem_cache.key?(cache_key)

    @permission_problem_cache[cache_key] = begin
      return if user&.administrator? || user&.projekt_manager&.allowed_to?(:manage, projekt)

      return :phase_not_active if not_active?
      return :phase_expired if expired?
      return :phase_not_current if not_current?

      return :guest_not_logged_in if user_status == "guest" && !user
      return if user_status == "guest"
      return :not_logged_in if !user || user&.guest?
      return :not_verified if user_status == "verified" && !user.level_three_verified?

      if phase_specific_permission_problems(user, location).present?
        return phase_specific_permission_problems(user, location)
      end

      return age_permission_problem(user) if age_permission_problem(user).present?
      return geozone_permission_problem(user) if geozone_permission_problem(user)
      return advanced_geozone_restriction_permission_problem(user) if advanced_geozone_restriction_permission_problem(user).present?
      return individual_group_value_permission_problem(user) if individual_group_value_permission_problem(user).present?

      nil
    end
  end

  def geozone_allowed?(user)
    geozone_permission_problem(user).present?
  end

  def geozone_restrictions_formatted
    return geozone_restrictions.map(&:name).flatten.join(", ") if geozone_restrictions.any?

    registered_address_districts.sort_by(&:name_for_display).map(&:name_for_display).join(", ")
  end

  def street_restrictions_formatted
    registered_address_streets.map(&:name).flatten.join(", ")
  end

  def age_restriction_formatted
    age_restriction.present? ? age_restriction.name.downcase : ""
  end

  def individual_group_value_restriction_formatted
    individual_group_values.map(&:name).flatten.join(", ")
  end

  def resource_count
    nil
  end

  def selectable_by_admins_only?
    false
  end

  def subscribed?(user)
    return false unless user

    subscriptions.where(user_id: user.id).exists?
  end

  def subscribe(user)
    return false unless user

    subscriptions.create(user_id: user.id)
  end

  def unsubscribe(user)
    return false unless user

    subscriptions.where(user_id: user.id).destroy_all
  end

  def title
    phase_tab_name.presence || model_name.human
  end

  def default_phase
    setting = projekt.projekt_settings.find_by(key: "projekt_custom_feature.default_footer_tab")
    setting&.value == id.to_s
  end

  def default_phase=(value)
    setting = projekt.projekt_settings.find_by(key: "projekt_custom_feature.default_footer_tab")
    return unless setting

    if ActiveModel::Type::Boolean.new.cast(value)
      setting.update!(value: id.to_s)
    elsif setting.value == id.to_s
      setting.update!(value: "")
    end
  end

  def all_settings
    @settings ||= settings.pluck(:key, :value)
  end

  def feature?(key)
    setting = settings.find { |s| s.key == "feature.#{key}" }

    if setting.present?
      setting.value.present?
    else
      false
    end
  end

  def option(key)
    option = settings.find { |s| s.key == "option.#{key}" }

    if option.present?
      option.value
    else
      nil
    end
  end

  def setting(key)
    setting = settings.find { |s| s.key == key }
  end

  def admin_nav_bar_items
    []
  end

  def embedded_admin_nav_bar_items
    admin_nav_bar_items
  end

  def settings_in_tabs
    {}
  end

  def settings_in_duration_tab
    {}
  end

  def safe_to_destroy?
    false
  end

  def projekt_labels_label_text
    labels_name.presence || I18n.t("custom.projekts.page.footer.sidebar.projekt_labels.title")
  end

  def sentiment_label_text
    sentiments_name.presence || I18n.t("custom.projekts.page.footer.sidebar.sentiments.title")
  end

  def map_location_with_admin_shape
    return nil unless map_location.present?

    map_location.show_admin_shape? ? map_location : nil
  end

  def subscribable?
    true
  end

  def regular_formular_cutoff_date
    setting = settings.find_by(key: "option.general.primary_formular_cutoff_date")
    setting&.value&.to_date
  rescue
    nil
  end

  def copy_map_settings_from_projekt
    return if map_location.present?

    map_location = projekt.map_location&.dup
    map_location.update!(mappable: self) if map_location.present?

    projekt.map_layers.each do |map_layer|
      map_layers << map_layer.dup
    end
  end

  def url
    projekt.page.url + "?projekt_phase_id=#{id}#projekt-footer"
  end

  def find_or_create_stats_version
    @find_or_create_stats_version ||= begin
      if stats_version.nil?
        create_stats_version
      elsif current? && stats_version.created_at < 10.minutes.ago
        stats_version.destroy!
        create_stats_version
      else
        stats_version
      end
    end
  end

  def voice_assistant_codename
    case self
    when ProjektPhase::ProposalPhase
      "proposal_voice_assistant"
    when ProjektPhase::BudgetPhase
      "budget_proposal_voice_assistant"
    end
  end

  def name
    if type.present? && type != self.class.name
      becomes(type.constantize).name
    else
      super
    end
  end

  def regular
    ProjektPhase::SPECIAL_PROJEKT_PHASES.exclude?(self.class.to_s)
  end

  def generate_ai_stats
    stats = AiAnalytics::GenerateAllStats.call(self)
    update_column(:ai_stats, stats)
  end

  def regular?
    ProjektPhase.regular_phases.include?(self)
  end

  def registered_address_grouping_restriction_formatted
    [
      registered_address_grouping_restriction,
      registered_address_grouping_restrictions[registered_address_grouping_restriction]
    ].compact.join(": ")
  end

  private

    def phase_specific_permission_problems(user, location)
      nil
    end

    def geozone_permission_problem(user)
      case geozone_restricted
      when "no_restriction" || nil
        nil
      when "only_citizens"
        return :missing_user_data if user.plz.blank?

        :only_citizens unless user.citizen?
      when "only_geozones"
        if user.plz.blank?
          :missing_user_data
        elsif (geozone_restrictions.any? && !geozone_restrictions.include?(user.geozone)) ||
               (registered_address_districts.any? && !registered_address_districts.include?(user.district))
          :only_specific_geozones
        end
      when "only_streets"
        if user.registered_address_street.blank?
          :no_registered_address
        elsif !registered_address_streets.include?(user.registered_address_street)
          :only_specific_streets
        end
      end
    end

    def advanced_geozone_restriction_permission_problem(user)
      return nil if registered_address_grouping_restriction.blank? || registered_address_grouping_restriction == "no_restriction"

      if user.registered_address.blank?
        :no_registered_address
      elsif !user_registered_address_permitted?(user)
        :only_specific_registered_address_groupings
      end
    end

    def user_registered_address_permitted?(user)
      registered_address_grouping_restrictions[registered_address_grouping_restriction]&.include?(user.registered_address.groupings[registered_address_grouping_restriction])
    end

    def age_permission_problem(user)
      return if age_restriction.nil?
      return :missing_user_data if user.age.blank?
      return if (age_restriction.min_age || 0) <= user.age && user.age <= (age_restriction.max_age || 200)

      :only_specific_ages
    end

    def individual_group_value_permission_problem(user)
      return nil if individual_group_values.blank?
      return nil if (individual_group_values & user.individual_group_values).any?

      :only_specific_individual_group_values
    end

    def touch_updated_at(geozone)
      touch if persisted?
    end

    def add_default_settings
      projekt_phase_settings = ProjektPhaseSetting.defaults[self.class.name]

      return if projekt_phase_settings.nil?

      ProjektPhaseSetting.defaults[self.class.name].each do |key, value|
        settings.create!(key:, value:)
      end
    end

    def type_must_be_valid
      if type.blank?
        errors.add(:type,
"is not included in the list of valid project phase types: #{PROJEKT_PHASES_TYPES.join(", ")}")
      elsif !PROJEKT_PHASES_TYPES.include?(type)
        errors.add(:type,
"is not included in the list of valid project phase types: #{PROJEKT_PHASES_TYPES.join(", ")}")
      end
    end
end
