class Whatsapp::Flows::ContributionsService < Whatsapp::Flows::BaseService
  # What this citizen has submitted, newest first. Answered as text rather than
  # as a tappable list: a row would have to lead somewhere, and the only place
  # to lead is the link the text already carries.
  #
  # Submissions still waiting on moderation are included and marked as such.
  # They are the ones a citizen is most likely to be looking for, and until now
  # there was nowhere at all to see them.
  MAX_SHOWN = 5

  # Both answers now end in the main menu. Neither used to carry anything: the
  # listing simply stopped, and the empty one told the citizen to tap "Beitrag
  # einreichen" on a message that had no buttons at all — which is also what
  # makes that sentence true again rather than something to rewrite.
  #
  # The listing keeps its text message and takes the menu as a second one. Five
  # entries of title, status and URL is long enough to pass what an interactive
  # body holds, and nothing truncates it, so pinning the pills to the list
  # itself would trade a dead end for a message that does not arrive.
  def call
    return send_empty if contributions.empty?

    Whatsapp::Send.text(
      account: account,
      body: [
        Whatsapp.phrase("whatsapp.bot.contributions.intro"),
        *entries,
        more_line
      ].compact_blank.join("\n\n")
    )

    Whatsapp::Flows::MainMenuService.follow_up(conversation: @conversation)
  end

  private

    def contributions
      @contributions ||= Whatsapp::UserContributionsQuery.call(user: @conversation.user)
    end

    def entries
      contributions.first(MAX_SHOWN).map { |resource| entry_for(resource) }
    end

    # A submission still awaiting moderation has no public page, so it is named
    # with its status and no link — the status line is what tells the author why
    # there is nothing to open yet.
    def entry_for(resource)
      url = Whatsapp::PublishedResourceUrl.call(resource)

      return entry_without_url(resource) if url.blank?

      I18n.t(
        "whatsapp.bot.contributions.entry",
        title: resource.title,
        status: status_for(resource),
        url: url
      )
    end

    def entry_without_url(resource)
      I18n.t(
        "whatsapp.bot.contributions.entry_without_url",
        title: resource.title,
        status: status_for(resource)
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
