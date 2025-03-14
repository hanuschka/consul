class Budget < ApplicationRecord
  include Measurable
  include Sluggable
  include StatsVersionable
  include Reportable
  include Imageable

  translates :name, :main_link_text, :main_link_url, touch: true
  include Globalizable

  # class Translation
  #   validate :name_uniqueness_by_budget

  #   def name_uniqueness_by_budget
  #     if Budget.joins(:translations)
  #              .where(name: name)
  #              .where.not("budget_translations.budget_id": budget_id).any?
  #       errors.add(:name, I18n.t("errors.messages.taken"))
  #     end
  #   end
  # end

  CURRENCY_SYMBOLS = %w[€ $ £ ¥].freeze
  VOTING_STYLES = %w[knapsack approval distributed].freeze

  validates_translation :name, presence: true
  validates_translation :main_link_url, presence: true, unless: -> { main_link_text.blank? }
  validates :phase, inclusion: { in: ->(*) { Budget::Phase::PHASE_KINDS }}
  validates :currency_symbol, presence: true
  validates :slug, presence: true, format: /\A[a-z0-9\-_]+\z/
  validates :voting_style, inclusion: { in: ->(*) { VOTING_STYLES }}

  has_many :investments, dependent: :destroy
  has_many :ballots, dependent: :destroy
  # has_many :groups, dependent: :destroy
  # has_many :headings, through: :groups
  has_many :lines, through: :ballots, class_name: "Budget::Ballot::Line"
  has_many :phases, class_name: "Budget::Phase"
  has_many :budget_administrators, dependent: :destroy
  has_many :administrators, through: :budget_administrators
  has_many :budget_valuators, dependent: :destroy
  has_many :valuators, through: :budget_valuators

  has_one :poll

  after_create :generate_phases
  accepts_nested_attributes_for :phases

  scope :published, -> { where(published: true) }
  scope :drafting,  -> { where.not(id: published) }
  scope :informing, -> { select(&:informing?) }
  scope :accepting, -> { select(&:accepting?) }
  scope :reviewing, -> { select(&:reviewing?) }
  scope :selecting, -> { select(&:selecting?) }
  scope :valuating, -> { select(&:valuating?) }
  scope :accepting_or_later, -> { select(&:accepting_or_later?) }
  scope :valuating_or_later, -> { select(&:valuating_or_later?) }
  scope :publishing_prices, -> { select(&:publishing_prices?) }
  scope :balloting, -> { select(&:balloting?) }
  scope :reviewing_ballots, -> { select(&:reviewing_ballots?) }
  scope :finished, -> { select(&:finished?) }

  class << self; undef :open; end
  scope :open, -> { where.not(phase: "finished") }

  def self.current
    published.order(:created_at).last
  end

  def self.process_preselected_investments
    where(phase: "selecting").find_each do |budget|
      return unless budget.current_phase.kind == "valuating"
      return unless budget.phase == "selecting"

      budget.update_column(:phase, "valuating")
      budget.update_preselected_investments
    end
  end

  def self.update_cached_current_phase
    where.not(phase: "finished").find_each(&:update_cached_current_phase)
  end

  def current_phase
    @current_phase ||= begin
      phases.published.where("starts_at < ? AND ends_at > ?", Time.zone.today, Time.zone.today).last ||
        phases.published.last ||
        phases.first
    end
  end

  def current_phase_index
    Budget::Phase::PHASE_KINDS.index(current_phase.kind) + 1
  end

  def published_phases
    phases.published.order(:id)
  end

  def starts_at
    phases.published.first&.starts_at
  end

  def ends_at
    phases.published.last&.ends_at
  end

  def description
    description_for_phase(phase)
  end

  def description_for_phase(phase)
    if phases.exists? && phases.send(phase).description.present?
      phases.send(phase).description
    else
      send("description_#{phase}")
    end
  end

  def self.title_max_length
    80
  end

  def publish!
    update!(published: true)
  end

  def drafting?
    !published?
  end

  def informing?
    current_phase.kind == "informing"
  end

  def accepting?
    current_phase.kind == "accepting"
  end

  def reviewing?
    current_phase.kind == "reviewing"
  end

  def selecting?
    current_phase.kind == "selecting"
  end

  def valuating?
    current_phase.kind == "valuating"
  end

  def publishing_prices?
    current_phase.kind == "publishing_prices"
  end

  def balloting?
    current_phase.kind == "balloting"
  end

  def reviewing_ballots?
    current_phase.kind == "reviewing_ballots"
  end

  def finished?
    current_phase.kind == "finished"
  end

  def published_prices?
    Budget::Phase::PUBLISHED_PRICES_PHASES.include?(phase)
  end

  def accepting_or_later?
    current_phase&.accepting_or_later?
  end

  def selecting_or_later?
    current_phase&.selecting_or_later?
  end

  def valuating_or_later?
    current_phase&.valuating_or_later?
  end

  def publishing_prices_or_later?
    current_phase&.publishing_prices_or_later?
  end

  def balloting_or_later?
    current_phase&.balloting_or_later?
  end

  def balloting_finished?
    balloting_or_later? && !balloting?
  end

  def single_group?
    # groups.one?
    true
  end

  def single_heading?
    # single_group? && headings.one?
    true
  end

  def heading_price(heading)
    heading.price || -1
  end

  def formatted_amount(amount)
    ActionController::Base.helpers.number_to_currency(amount,
                                                      precision: 0,
                                                      locale: I18n.locale,
                                                      unit: currency_symbol,
                                                      delimiter: ( I18n.locale == :de ? '.' : ',' )
                                                     )
  end

  def formatted_heading_price(heading)
    formatted_amount(heading_price(heading))
  end

  def investments_orders
    case phase
    when "accepting", "reviewing", "finished"
      %w[random]
    when "publishing_prices", "balloting", "reviewing_ballots"
      hide_money? ? %w[random] : %w[random price]
    else
      %w[random confidence_score]
    end
  end

  def investments_filters
    [
      ("winners" if finished?),
      ("selected" if publishing_prices_or_later? && !finished?),
      ("unselected" if publishing_prices_or_later?),
      ("not_unfeasible" if valuating?),
      ("unfeasible" if valuating_or_later?)
    ].compact
  end

  def email_selected
    investments.selected.order(:id).each do |investment|
      Mailer.budget_investment_selected(investment).deliver_later
    end
  end

  def email_unselected
    investments.unselected.order(:id).each do |investment|
      Mailer.budget_investment_unselected(investment).deliver_later
    end
  end

  def has_winning_investments?
    investments.winners.any?
  end

  def investments_milestone_tags
    investments.winners.map(&:milestone_tag_list).flatten.uniq.sort
  end

  def approval_voting?
    voting_style == "approval"
  end

  def show_money?
    !hide_money?
  end

  def update_preselected_investments
    investments.update_all(preselected: false)

    preselected_investments_ids = investments.sort_by_total_votes.limit(max_preselected).ids
    preselected_investments = investments.where(id: preselected_investments_ids)

    preselected_investments.update_all(preselected: true)

    investments.each do |investment|
      if investment.preselected?
        Mailer.budget_investment_preselected(investment).deliver_later
      else
        Mailer.budget_investment_not_preselected(investment).deliver_later
      end
    end
  end

  def update_cached_current_phase
    current_phase_kind = current_phase.kind
    return if current_phase_kind == phase

    update_column(:phase, current_phase_kind)
  end

  private

    def generate_phases
      Budget::Phase::PHASE_KINDS.each do |phase|
        Budget::Phase.create(
          budget: self,
          kind: phase,
          name: I18n.t("budgets.phase.#{phase}"),
          prev_phase: phases&.last,
          starts_at: phases&.last&.ends_at || Date.current,
          ends_at: (phases&.last&.ends_at || Date.current) + 1.month
        )
      end
    end

    def generate_slug?
      slug.nil? || drafting?
    end
end
