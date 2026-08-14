class Whatsapp::Flows::ContributionsService < Whatsapp::Flows::BaseService
  # What this citizen has submitted, newest first. Answered as text rather than
  # as a tappable list: a row would have to lead somewhere, and the only place
  # to lead is the link the text already carries.
  #
  # Submissions still waiting on moderation are included and marked as such.
  # They are the ones a citizen is most likely to be looking for, and until now
  # there was nowhere at all to see them.
  MAX_SHOWN = 5

  # Both messages end in the main menu's own three options. Neither used to
  # carry anything: the listing simply stopped, and the empty one told the
  # citizen to tap "Beitrag einreichen" on a message that had no buttons at
  # all — which is also what makes that sentence true again rather than
  # something to rewrite.
  def call
    return send_empty if contributions.empty?

    Whatsapp::Send.buttons(
      account: account,
      body: [
        Whatsapp.phrase("whatsapp.bot.contributions.intro"),
        *entries,
        more_line
      ].compact_blank.join("\n\n"),
      buttons: Whatsapp::FlowActions.main_menu_buttons
    )
  end

  private

    def contributions
      @contributions ||= Whatsapp::UserContributionsQuery.call(user: @conversation.user)
    end

    def entries
      contributions.first(MAX_SHOWN).map { |resource| entry_for(resource) }
    end

    def entry_for(resource)
      I18n.t(
        "whatsapp.bot.contributions.entry",
        title: resource.title,
        status: status_for(resource),
        url: Whatsapp::PublishedResourceUrl.call(resource)
      )
    end

    # Investments have no admin_accepted column — the budget flow publishes them
    # outright — so moderation stays a proposal concern here as it does at
    # publish time.
    def status_for(resource)
      return I18n.t("whatsapp.bot.contributions.status.published") if !resource.is_a?(::Proposal)
      return I18n.t("whatsapp.bot.contributions.status.published") if resource.admin_accepted?

      I18n.t("whatsapp.bot.contributions.status.pending")
    end

    def more_line
      remaining = contributions.size - MAX_SHOWN

      return if remaining < 1

      Whatsapp.phrase("whatsapp.bot.contributions.more", count: remaining)
    end

    def send_empty
      Whatsapp::Send.buttons(
        account: account,
        body: Whatsapp.phrase("whatsapp.bot.contributions.empty"),
        buttons: Whatsapp::FlowActions.main_menu_buttons
      )
    end
end
