module Searchable
  extend ActiveSupport::Concern

  included do
    include PgSearch::Model
    include SearchCache

    # The two questions the same index answers. `pg_search` is the search box:
    # every word the person typed must appear, and a half-typed last word still
    # matches. `pg_search_any_word` matches one whole text against another —
    # a citizen's idea against existing contributions — where requiring all of
    # a paragraph's words matches nothing and prefix-matching every one of them
    # sweeps most of the table.
    #
    # Built from one options hash rather than two declarations: the tsvector
    # column and the dictionary selector are what this concern knows on behalf
    # of eleven models, and a fork of them drifts silently — the search that
    # kept the stale config would simply stop finding anything.
    def self.tsearch_options(query, tsearch: {})
      cached_votes_up_present = column_names.include?("cached_votes_up")

      {
        against: :ignored, # not used since using a tsvector_column
        using: {
          tsearch: {
            tsvector_column: "tsv",
            dictionary: SearchDictionarySelector.call
          }.merge(tsearch)
        },
        ignoring: :accents,
        ranked_by: "(:tsearch)",
        order_within_rank: (cached_votes_up_present ? "#{table_name}.cached_votes_up DESC" : nil),
        query: query
      }
    end

    pg_search_scope :pg_search, ->(query) do
      tsearch_options(query, tsearch: { prefix: true })
    end

    pg_search_scope :pg_search_any_word, ->(query) do
      tsearch_options(query, tsearch: { any_word: true })
    end
  end
end
