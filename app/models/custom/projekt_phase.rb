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
    "ProjektPhase::NewsfeedPhase",
    "ProjektPhase::MitmachboxPhase"
  ].freeze

  DEPRECATED_PHASE_TYPES = [
    "ProjektPhase::DebatePhase"
  ].freeze

  ALL_PHASE_TYPES = (PROJEKT_PHASES_TYPES + DEPRECATED_PHASE_TYPES).freeze

  SPECIAL_PROJEKT_PHASES = [
    "ProjektPhase::MilestonePhase",
    "ProjektPhase::ProjektNotificationPhase",
    "ProjektPhase::EventPhase",
    "ProjektPhase::ArgumentPhase",
    "ProjektPhase::NewsfeedPhase",
    "ProjektPhase::MitmachboxPhase"
  ].freeze

  PHASE_MATERIAL_ICONS = {
    "ProjektPhase::CommentPhase" => "chat_bubble",
    "ProjektPhase::ProposalPhase" => "lightbulb",
    "ProjektPhase::PointOfInterestPhase" => "location_on",
    "ProjektPhase::QuestionPhase" => "quiz",
    "ProjektPhase::VotingPhase" => "how_to_vote",
    "ProjektPhase::IframePhase" => "web",
    "ProjektPhase::BudgetPhase" => "euro_symbol",
    "ProjektPhase::LegislationPhase" => "gavel",
    "ProjektPhase::FormularPhase" => "description",
    "ProjektPhase::EventPhase" => "event",
    "ProjektPhase::MilestonePhase" => "flag",
    "ProjektPhase::ProjektNotificationPhase" => "notifications",
    "ProjektPhase::LivestreamPhase" => "live_tv",
    "ProjektPhase::ArgumentPhase" => "forum",
    "ProjektPhase::NewsfeedPhase" => "feed",
    "ProjektPhase::MitmachboxPhase" => "markunread_mailbox",
    "ProjektPhase::DebatePhase" => "forum"
  }.freeze

  DEFAULT_PHASE_MATERIAL_ICON = "flag".freeze

  FOOTER_HIDDEN_EVALUATION_SECTIONS = %w[kpis heatmap].freeze

  # Every place a citizen can start a submission, and so every place the
  # per-user submission cap has to be enforced. The bot belongs here for the
  # same reason the new-proposal button does: naming only one of them lets the
  # other channel publish past the limit.
  SUBMISSION_LOCATIONS = %i[new_button_component whatsapp_bot].freeze

  # A guest phase waives its own participation restrictions, which is right for
  # a form the citizen fills in on the projekt page: they got there through the
  # projekt, and the page is the gate. A channel that accepts submissions from
  # anywhere has no such gate, so the restrictions are asked for after all.
  #
  # Named as a location rather than checked at the call site so the order of the
  # checks above it — phase active, not expired, still current — stays the one
  # canonical sequence every channel runs.
  GUEST_WAIVER_EXEMPT_LOCATIONS = %i[whatsapp_bot].freeze

  # Phase types the AI drafting flow exists for override this with their own
  # feature key. Nil means the type has no such flow, which is what every
  # caller — the new-proposal button, the /adm toggle, the WhatsApp bot — has
  # to branch on, so the branch lives here rather than once per caller.
  def ai_flow_feature_key
    nil
  end

  def ai_flow_enabled?
    ai_flow_feature_key.present? && feature?(ai_flow_feature_key)
  end

  PHASE_FA_ICONS = {
    "ProjektPhase::CommentPhase" => "fa-comment",
    "ProjektPhase::ProposalPhase" => "fa-lightbulb",
    "ProjektPhase::PointOfInterestPhase" => "fa-map-marker-alt",
    "ProjektPhase::QuestionPhase" => "fa-question-circle",
    "ProjektPhase::VotingPhase" => "fa-vote-yea",
    "ProjektPhase::IframePhase" => "fa-globe",
    "ProjektPhase::BudgetPhase" => "fa-euro-sign",
    "ProjektPhase::LegislationPhase" => "fa-gavel",
    "ProjektPhase::FormularPhase" => "fa-file-alt",
    "ProjektPhase::EventPhase" => "fa-calendar-alt",
    "ProjektPhase::MilestonePhase" => "fa-flag",
    "ProjektPhase::ProjektNotificationPhase" => "fa-bell",
    "ProjektPhase::LivestreamPhase" => "fa-tv",
    "ProjektPhase::ArgumentPhase" => "fa-comments",
    "ProjektPhase::NewsfeedPhase" => "fa-rss",
    "ProjektPhase::MitmachboxPhase" => "fa-box-open",
    "ProjektPhase::DebatePhase" => "fa-comments"
  }.freeze

  DEFAULT_PHASE_FA_ICON = "fa-flag".freeze

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
  has_one :projekt_phase_evaluation_visibility, dependent: :destroy
  has_one :projekt_phase_evaluation, dependent: :destroy

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
  has_many :email_templates, class_name: "SiteCustomization::EmailTemplate", dependent: :destroy
  has_many :masterportal_pins, dependent: :destroy
  has_many :masterportal_collections, dependent: :destroy

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

  enum masterportal_import_status: {
    pending: "pending",
    running: "running",
    success: "success",
    failed: "failed"
  }, _prefix: :masterportal_import

  enum masterportal_destroy_status: {
    pending: "pending",
    running: "running",
    success: "success",
    failed: "failed"
  }, _prefix: :masterportal_destroy

  validates :projekt, presence: true
  validate :type_must_be_valid

  def self.find_sti_class(type_name)
    if ALL_PHASE_TYPES.include?(type_name)
      super
    else
      self
    end
  rescue NameError
    self
  end

  def self.type_labels
    PROJEKT_PHASES_TYPES.index_with { |phase_type| type_label_for(phase_type) }
  end

  def self.type_label_for(type)
    label = I18n.t("activerecord.models.#{type.to_s.underscore}", default: nil)

    return type.to_s.demodulize.titleize if !label.is_a?(String)

    label
  end

  def self.material_icon_for(type)
    PHASE_MATERIAL_ICONS[type.to_s] || DEFAULT_PHASE_MATERIAL_ICON
  end

  def material_icon
    self.class.material_icon_for(type)
  end

  def self.fa_icon_for(type)
    PHASE_FA_ICONS[type.to_s] || DEFAULT_PHASE_FA_ICON
  end

  def fa_icon
    self.class.fa_icon_for(type)
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

  # Phases of a projekt a visitor can actually reach: activated, and with its
  # page published. Anything offered outside a session — the WhatsApp bot, a
  # digest — has to narrow by this before it links to a phase.
  scope :of_publicly_visible_projekt, -> {
    joins(projekt: :page)
      .where(site_customization_pages: { status: "published" })
      .merge(Projekt.activated)
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

  def selectable_by?(user, resource = nil)
    # return true if resource&.respond_to?(:author) && resource.author == user
    return false if selectable_by_admins_only? && !user.has_pm_permission_to?("manage", projekt)

    permission_problem(user, location: :new_button_component).blank?
  end

  def votable_by?(user, resource = nil)
    permission_problem(user, location: :votes_component).blank? || conditional_vote_possible_for?(user)
  end

  def conditional_vote_possible_for?(user)
    permission_problem(user, location: :votes_component) == :not_verified &&
      feature?("resource.conditional_voting")
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
    hidden_at.blank? &&
      active? &&
      type != "ProjektPhase::DebatePhase" &&
      (start_date.blank? || start_date <= timestamp) &&
      (end_date.blank? || end_date >= timestamp)
  end

  def not_current?
    !current?
  end

  def permission_problem(user, location: nil)
    location = location&.to_sym
    @permission_problem_cache ||= {}
    cache_key = "#{user&.id}_#{location}"

    unless @permission_problem_cache.key?(cache_key)
      @permission_problem_cache[cache_key] = uncached_permission_problem(user, location)
    end

    @permission_problem_cache[cache_key]
  end

  # The cache above is a per-request read cache, and some answers depend on what the user has
  # already submitted or supported. A request that *writes* one of those has to drop it before
  # re-rendering anything, otherwise it reports the state from before its own write. Casting a
  # support is the case that matters: register_selection asks the question on its way in, so the
  # answer is cached while the vote row still does not exist.
  def reset_permission_problem_cache!
    @permission_problem_cache = nil
  end

  # Whether this phase accepts submissions from someone with no account. Asked
  # in enough places — the bot's dispatcher, its author resolution, its eligible
  # phases query — that the string comparison is worth having exactly once.
  def guest_participation?
    user_status == "guest"
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

  def settings_by_key
    @settings_by_key ||= settings.each_with_object({}) do |setting, values|
      values[setting.key] = setting.value
    end
  end

  def all_settings
    settings_by_key.to_a
  end

  def feature?(key)
    settings_by_key["feature.#{key}"].present?
  end

  # Mirrors the footer partials' map gate: proposal/budget phases render their
  # resource map only when "form.show_map" is enabled; phase types without the
  # setting (e.g. point of interest) always show it.
  def resource_map_enabled?
    return true if !settings_by_key.key?("feature.form.show_map")

    settings_by_key["feature.form.show_map"].present?
  end

  def publicly_visible?
    active? && frontend_visibility?
  end

  def evaluation_completed?
    projekt_phase_evaluation.present? && projekt_phase_evaluation.completed?
  end

  def publicly_visible_evaluation_tabs
    visibility = projekt_phase_evaluation_visibility
    return [] if visibility.blank?

    evaluation_data = projekt_phase_evaluation&.data || {}
    available = ::PdfServices::EvaluationPdfSelection.available_sections(type)
    visible = visibility.visible_sections & available
    footer_visible = visible - FOOTER_HIDDEN_EVALUATION_SECTIONS
    present = footer_visible.select do |key|
      ::ProjektEvaluations::SectionDataPresence.has_data?(evaluation_data, key)
    end
    ai_keys = ::Adm::Projekts::EvaluationHelper::EVALUATION_AI_SECTIONS

    tabs = []
    tabs << "poll_stats" if visibility.show_poll_stats
    tabs << "stats" if present.any? { |key| !ai_keys.include?(key) }
    tabs << "ai" if present.any? { |key| ai_keys.include?(key) }

    tabs
  end

  def evaluation_tab_publicly_visible?(tab)
    if evaluation_completed?
      publicly_visible_evaluation_tabs.include?(tab)
    elsif tab == "ai"
      feature?("general.public_ai_stats")
    else
      feature?("general.public_kpi_stats")
    end
  end

  def max_submissions_per_user
    option("resource.max_submissions_per_user").to_i
  end

  def max_supports_per_user
    option("resource.max_supports_per_user").to_i
  end

  def option(key)
    settings_by_key["option.#{key}"]
  end

  def setting(key)
    setting = settings.find { |s| s.key == key }
  end

  def customizable_email_templates
    raise NotImplementedError, "#{self.class.name} must implement #customizable_email_templates"
  end

  def customizable_email_template_groups
    [
      {
        key: nil,
        templates: customizable_email_templates.map do |mailer_class, mailer_action|
          { mailer_class: mailer_class, mailer_action: mailer_action, recipient_type: nil }
        end
      }
    ]
  end

  def admin_nav_bar_items
    []
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

  def use_masterportal_collections_as_labels?
    feature?("form.use_masterportal_collections_as_labels") && masterportal_collections.exists?
  end

  def active_projekt_labels
    active_masterportal_taxonomy(projekt_labels)
  end

  def active_projekt_point_of_interest_categories
    active_masterportal_taxonomy(projekt_point_of_interest_categories)
  end

  def active_masterportal_taxonomy(scope)
    use_masterportal_collections_as_labels? ? scope.collection_backed : scope.manual
  end

  def labels_selector_available?
    (use_masterportal_collections_as_labels? || feature?("form.labels")) && active_projekt_labels.exists?
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

  # SiteCustomization::Page#url is path-only, which is enough inside a request
  # but not for links written into stored content (content blocks, exports,
  # anything a job generates).
  def absolute_url
    options = UrlOptions.default || {}
    host = options[:host]
    return url if host.blank?

    "#{options[:protocol].presence || 'https'}://#{host}#{url}"
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

  # Which call-to-action the projekt page sidebar renders for this phase.
  # Returns nil (no CTA) by default; subclasses opt in by returning a symbol
  # (:new_button, :link or :poll) and may decide it from their own state.
  # See Pages::Projekts::SidebarCtaComponent.
  def sidebar_cta_kind
    nil
  end

  # Label for the sidebar CTA. Defaults to the per-phase i18n string (with the
  # admin's cta_button_name override). Subclasses whose label varies by state
  # (e.g. BudgetPhase) override this.
  def sidebar_cta_label
    cta_button_name.presence || I18n.t("custom.projekt_phases.cta.#{name}")
  end

  # DOM id the sidebar CTA link scrolls to. Defaults to the footer phase
  # subnav; subclasses override to target a more specific element.
  def sidebar_cta_anchor
    "filter-subnav"
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

    def uncached_permission_problem(user, location)
      return if user&.administrator? || user&.projekt_manager&.allowed_to?(:manage, projekt)

      return :phase_not_active if not_active?

      unless location == :officing && lock_on.present? && lock_on >= Time.zone.today
        return :phase_expired if expired?
        return :phase_not_current if not_current?
      end

      return :guest_not_logged_in if guest_participation? && !user
      return if guest_participation? && !GUEST_WAIVER_EXEMPT_LOCATIONS.include?(location)
      return :not_logged_in if user.blank? || (user.guest? && !guest_participation?)
      return :not_verified if user_status == "verified" && !user.level_three_verified?

      restriction_problem(user, location: location)
    end

    # The who-may-take-part restrictions on their own, below the account rules
    # that precede them. Split out of the sequence above so the guest waiver can
    # skip exactly these and nothing else — the phase-lifecycle checks are not
    # waivable by anyone.
    def restriction_problem(user, location: nil)
      phase_specific_problem = phase_specific_permission_problems(user, location)
      return phase_specific_problem if phase_specific_problem.present?

      return age_permission_problem(user) if age_permission_problem(user).present?
      return geozone_permission_problem(user) if geozone_permission_problem(user)

      advanced_geozone_problem = advanced_geozone_restriction_permission_problem(user)
      return advanced_geozone_problem if advanced_geozone_problem.present?

      individual_group_value_permission_problem(user)
    end

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
"is not included in the list of valid project phase types: #{ALL_PHASE_TYPES.join(", ")}")
      elsif !ALL_PHASE_TYPES.include?(type)
        errors.add(:type,
"is not included in the list of valid project phase types: #{ALL_PHASE_TYPES.join(", ")}")
      end
    end
end
