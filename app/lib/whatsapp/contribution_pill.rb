module Whatsapp::ContributionPill
  # The pill that opens one contribution, composed and resolved in one place
  # because both lists that offer one — the citizen's own history and a projekt's
  # contributions — have to compose the same id, and the inbound side has to read
  # it back.
  #
  # A contribution is either a proposal or a budget investment: the submission
  # flow picks one by phase and the citizen calls both a Beitrag, so the kind
  # travels beside the id rather than being guessed from it.
  #
  # Joined with an underscore because a pill parameter is matched against
  # [a-z0-9_]+ and nothing else: a dash composes here without complaint and then
  # fails to parse on the tap, which is a pill that does nothing and says nothing.
  KINDS = {
    "proposal" => ::Proposal,
    "investment" => ::Budget::Investment
  }.freeze

  module_function

  # Nil for anything that is neither kind, which leaves the row without an action
  # id rather than offering one nothing can resolve.
  def id_for(contribution)
    param = param_for(contribution)

    return if param.blank?

    ::Whatsapp::FlowActions.id_for(action: :view_contribution, param: param)
  end

  def param_for(contribution)
    kind, = KINDS.find { |_name, model| contribution.is_a?(model) }

    return if kind.blank?

    "#{kind}_#{contribution.id}"
  end

  # The record as it stands now, never as it stood when the pill was sent — the
  # rule every other parameterised pill is resolved under. A pill sits in a chat
  # history for as long as the chat does, and what it points at may have been
  # withdrawn, hidden or retired since. Takes the parameter rather than the whole
  # id, because by the time this is asked Whatsapp::FlowActions.parse has already
  # said which action arrived.
  #
  # Only what this citizen may open, and nil for the rest exactly as for a record
  # that is gone: a pill carries whatever id it was given, and the title read off
  # someone else's draft is the title the row and the reply would then name.
  def resolve(param, user:)
    model, id = split(param)
    scope = openable_scope(model, user)

    return if scope.blank?

    scope.find_by(id: id)
  end

  # #resolve for one message's pills at once: a query per kind rather than one per
  # pill, answered the same way — nil for anything this citizen may not open — and
  # keyed by the parameter as it was given.
  def resolve_all(params, user:)
    pills = Array(params).map(&:to_s).uniq.index_with { |param| split(param) }

    found =
      pills.values.compact.group_by(&:first).to_h do |model, pairs|
        records = openable_scope(model, user).where(id: pairs.map(&:last)).index_by(&:id)

        [model, records]
      end

    pills.transform_values { |(model, id)| found.dig(model, id) }
  end

  # The model and the id a parameter names, or nil for one naming neither kind.
  def split(param)
    kind, id = param.to_s.rpartition("_").values_at(0, 2)
    model = KINDS[kind]

    return if model.blank?
    return if !id.match?(/\A\d+\z/)

    [model, id.to_i]
  end

  def openable_scope(model, user)
    if model == ::Proposal
      return ::Whatsapp::ReachableContributionsQuery.openable_proposals(user: user)
    end

    return if model != ::Budget::Investment

    ::Whatsapp::ReachableContributionsQuery.openable_investments(user: user)
  end
end
