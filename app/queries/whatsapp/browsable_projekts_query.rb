class Whatsapp::BrowsableProjektsQuery < ApplicationQuery
  # Reading is a wider set than submitting: a projekt worth browsing is one the
  # portal's own overview shows, not only one whose phase happens to accept a
  # submission from the bot.
  #
  # Which means the two sets come apart, and the difference is what the bot has to
  # say out loud: a projekt listed here may have nothing open to contribute to, and
  # offering a submission into it would be an offer refused on the next tap. Which
  # of them can be is BaseTool#open_phase_counts, asked once for the whole list.

  # Everything the overview holds, for callers that count what is running or
  # resolve a projekt a citizen named rather than fill a list. The display cap is
  # about what fits in one message, not about what is open.
  def self.uncapped
    new.uncapped
  end

  def initialize(from: 0)
    @from = from
  end

  # One page of the list the bot sends. Paged in Ruby rather than in SQL so that
  # #total is the same set counted, not a second query that could disagree with it.
  def call
    ::Whatsapp::ListWindow.page(uncapped, from: @from)
  end

  def exists?
    scope.exists?
  end

  # Memoised because #call, #total and the row builder all read it, and the page
  # associations it carries are the expensive half.
  def uncapped
    @uncapped ||= scope.to_a
  end

  # How many are underway altogether, so a capped page can say what it left out.
  def total
    uncapped.size
  end

  private

    # Translations because every caller that lists these projekts names them, and
    # both Whatsapp::ProjektLink.title and Whatsapp::ProjektCard.subtitle read the
    # translated page — one query per row of a list otherwise.
    def scope
      Projekt.index_order_underway.includes(page: :translations)
    end
end
