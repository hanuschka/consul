class WhatsappBrowsableProjektsQuery < ApplicationQuery
  # A WhatsApp list holds ten rows, and the bot has nowhere to paginate to.
  MAX_CHOICES = 10

  # Reading is a wider set than submitting: a projekt worth browsing is one the
  # portal's own overview shows, not only one whose phase happens to accept a
  # submission from the bot.
  def call
    Projekt
      .index_order_underway
      .includes(:page)
      .limit(MAX_CHOICES)
      .to_a
  end
end
