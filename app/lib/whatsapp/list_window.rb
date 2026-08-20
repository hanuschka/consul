module Whatsapp::ListWindow
  # One page of a list the bot sends, and what it owes the model about the rest.
  #
  # Every list the bot can send is capped at ten rows, and until now a capped list
  # said nothing about what it cut: two of the tools reported a total beside their
  # rows, the other three reported the rows alone, so on a portal with forty open
  # phases the model answered "ten projekts are running" and had no way to know
  # otherwise. Reporting the same four numbers from one place is what lets the
  # reply say how many there are altogether and offer the rest behind one tap,
  # rather than falling back to a plain list of names.
  #
  # Where the citizen is in the list travels through the conversation rather than
  # through the tapped id: `show_more`'s parameter names *which* list, because a
  # scope name is all the inbound side can safely resolve, and the offset is the
  # `next_from` the model was handed with the page it just showed.
  ROWS = ::Whatsapp::MAX_LIST_ROWS

  module_function

  # A row offset from whatever the model passed. Clamped rather than validated: a
  # negative or non-numeric `from` is the first page, which is the answer the
  # citizen can read, where an error is a turn spent on arithmetic.
  def offset(from)
    [from.to_i, 0].max
  end

  # How many rows to load to answer a window that is filtered in Ruby afterwards.
  # A query that selects rows after loading them cannot offset in SQL, so it loads
  # up to the end of the window and drops the pages before it.
  def limit_through(from)
    offset(from) + ROWS
  end

  # The window itself, for the queries whose rows are decided in Ruby.
  def page(rows, from:)
    rows.drop(offset(from)).first(ROWS)
  end

  # What the tool reports beside its rows. `next_from` is present only when there
  # is a page behind this one, so its absence is the model's signal that this is
  # everything — and `more_action_id` is absent with it, because a pill offering
  # rows that do not exist is one the citizen taps for nothing.
  def report(scope:, from:, shown:, total:)
    reached = offset(from) + shown
    remaining = [total - reached, 0].max

    {
      shown: shown,
      total: total,
      from: offset(from),
      remaining: remaining,
      next_from: remaining.positive? ? reached : nil,
      more_action_id: remaining.positive? ? more_action_id(scope) : nil
    }.compact
  end

  # Built here rather than written into five tool descriptions, so a scope name
  # that is not one cannot reach a citizen's screen as a pill: the id is composed
  # from the same allowlist the inbound side checks it against.
  def more_action_id(scope)
    return if !::Whatsapp::FlowActions::MORE_SCOPES.include?(scope.to_s)

    ::Whatsapp::FlowActions.id_for(action: :show_more, param: scope)
  end
end
