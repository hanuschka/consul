class Adm::Whatsapp::DialogsQuery < ApplicationQuery
  RECENT_WINDOW = 7.days
  GROWTH_WINDOW = 30.days

  ACTIVITY_OPTIONS = %w[recent month stale].freeze

  ORDER_CLAUSE =
    "COALESCE(whatsapp_accounts.last_inbound_at, whatsapp_accounts.created_at) DESC".freeze

  def initialize(base_scope, params = {})
    @base_scope = base_scope
    @params = params
  end

  def call
    base_scope
      .then { |scope| filter_by_search(scope) }
      .then { |scope| filter_by_state(scope) }
      .then { |scope| filter_by_step(scope) }
      .then { |scope| filter_by_activity(scope) }
      .order(Arel.sql(ORDER_CLAUSE))
  end

  private

    attr_reader :base_scope, :params

    def filter_by_search(scope)
      return scope if params[:q].blank?

      pattern = "%#{escape_like(params[:q].strip)}%"

      scope.where(
        "whatsapp_accounts.phone ILIKE :pattern
          OR whatsapp_accounts.profile_name ILIKE :pattern
          OR whatsapp_accounts.wa_id ILIKE :pattern",
        pattern: pattern
      )
    end

    def filter_by_state(scope)
      return scope if params[:state].blank?
      return scope if !::Whatsapp::Account.states.key?(params[:state])

      scope.where(state: params[:state])
    end

    def filter_by_step(scope)
      return scope if params[:step].blank?
      return scope if !::Whatsapp::Conversation.steps.key?(params[:step])

      scope
        .joins(:whatsapp_conversation)
        .where(whatsapp_conversations: { step: params[:step] })
    end

    def filter_by_activity(scope)
      case params[:activity]
      when "recent" then scope.where(last_inbound_at: RECENT_WINDOW.ago..)
      when "month" then scope.where(last_inbound_at: GROWTH_WINDOW.ago..)
      when "stale" then scope.where("last_inbound_at IS NULL OR last_inbound_at < ?", GROWTH_WINDOW.ago)
      else scope
      end
    end
end
