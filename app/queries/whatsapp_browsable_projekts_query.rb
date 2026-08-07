class WhatsappBrowsableProjektsQuery < ApplicationQuery
  # Reading is a wider set than submitting: a projekt worth browsing is one the
  # portal's own overview shows, not only one whose phase happens to accept a
  # submission from the bot.
  def call
    scope.includes(:page).limit(::Whatsapp::MAX_LIST_ROWS).to_a
  end

  def exists?
    scope.exists?
  end

  private

    def scope
      Projekt.index_order_underway
    end
end
