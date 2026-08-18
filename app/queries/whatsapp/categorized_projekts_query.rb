class Whatsapp::CategorizedProjektsQuery < ApplicationQuery
  # The portal's own overview tabs, as the four groups the browse digest is
  # built from (CON-2967). Reading is a wider set than submitting, and wider
  # again than BrowsableProjektsQuery's: a citizen browsing the portal is shown
  # the projekts whose participation is over or has not started too, with the
  # group saying which is which.
  #
  # Explicit lambdas rather than a scope name derived from the key, the same
  # way ProjektsController::INDEX_FILTERS keeps them: the key travels on a
  # tapped pill, and `send` on a parameter is how a chat message reaches a
  # scope nobody meant to expose.
  CATEGORY_SCOPES = {
    "index_order_underway" => -> { Projekt.index_order_underway },
    "index_order_ongoing" => -> { Projekt.index_order_ongoing },
    "index_order_upcoming" => -> { Projekt.index_order_upcoming },
    "index_order_expired" => -> { Projekt.index_order_expired }
  }.freeze

  MAX_PER_CATEGORY = 5

  # Short enough that a phase opening or a projekt being published reaches the
  # bot within the minute, long enough that the "show more" taps a citizen
  # makes while reading one digest are all answered from one round of counting.
  CACHE_TTL = 1.minute

  # The rest of one group, for the pill the digest offers when a group was cut.
  # Capped at the list cap rather than uncapped: a portal with sixty completed
  # projekts would otherwise answer one tap with all of them.
  def self.category(key:)
    new(key: key).category
  end

  def initialize(key: nil)
    @key = key
  end

  def call
    groups(CATEGORY_SCOPES.keys.map { |key| window(key, limit: MAX_PER_CATEGORY, offset: 0) })
  end

  def category
    return if !CATEGORY_SCOPES.key?(@key)

    groups([window(@key, limit: ::Whatsapp::MAX_LIST_ROWS, offset: MAX_PER_CATEGORY)]).first
  end

  private

    # Ids and a count rather than the records themselves. Two of the four scopes
    # decide membership through an EXISTS over projekt_phases, so the browse
    # digest cost eight of those per tap and paid them again for every "show
    # more" — while the answer changes only when a phase opens or closes.
    #
    # What is cached is deliberately the thin half: an ActiveRecord object in a
    # shared store is a copy of the row and of the schema that loaded it, an id
    # stays true, and the records are read back below through a scope that
    # re-applies the portal's own visibility gate.
    #
    # `total` is counted rather than inferred from the ids: the digest has to
    # say how many were left out, which the capped window cannot answer.
    def window(key, limit:, offset:)
      Rails.cache.fetch(cache_key(key, limit: limit, offset: offset), expires_in: CACHE_TTL) do
        scope = CATEGORY_SCOPES.fetch(key).call

        {
          key: key,
          total: scope.count,
          ids: scope.offset(offset).limit(limit).ids
        }
      end
    end

    def cache_key(key, limit:, offset:)
      ["whatsapp/categorized_projekts", key, offset, limit, Date.current].join("/")
    end

    # One load for every group rather than one per group, ordered by the cached
    # ids because `where(id:)` does not preserve them — the scopes' created_at
    # DESC ordering lives in the cached window now.
    #
    # Read back through index_order_all so a projekt unpublished, deactivated or
    # taken off the overview inside the cache window disappears from the bot at
    # once: the count it left behind is a minute stale, its visibility is not.
    def groups(windows)
      filled = windows.reject { |window| window[:ids].empty? }

      return [] if filled.empty?

      projekts = projekts_by_id(filled.flat_map { |window| window[:ids] })

      filled.filter_map do |window|
        projekts_in_window = window[:ids].filter_map { |id| projekts[id] }

        next if projekts_in_window.empty?

        { key: window[:key], total: window[:total], projekts: projekts_in_window }
      end
    end

    def projekts_by_id(ids)
      Projekt.index_order_all.where(id: ids).includes(:page).index_by(&:id)
    end
end
