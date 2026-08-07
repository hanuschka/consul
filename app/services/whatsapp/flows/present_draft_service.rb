class Whatsapp::Flows::PresentDraftService < ApplicationService
  DESCRIPTION_PREVIEW_LENGTH = 700

  # Catalog C16 and C18 — the same card, with different copy the second time so
  # a citizen who asked for a change can tell that the change landed. The draft
  # is always shown for active confirmation; nothing here publishes.
  def self.first_draft(conversation:)
    new(conversation: conversation, copy_key: "whatsapp.bot.proposal.draft").call
  end

  def self.revised_draft(conversation:)
    new(conversation: conversation, copy_key: "whatsapp.bot.proposal.draft_revised").call
  end

  def initialize(conversation:, copy_key: "whatsapp.bot.proposal.draft")
    @conversation = conversation
    @copy_key = copy_key
  end

  def call
    @conversation.update!(step: "awaiting_draft_decision")

    Whatsapp::Outbound.buttons(
      account: @conversation.whatsapp_account,
      body: draft_summary,
      buttons: buttons
    )
  end

  private

    def draft_resource
      @conversation.draft_resource
    end

    def draft_summary
      [
        I18n.t(@copy_key, title: draft_resource.title, description: plain_description),
        category_line,
        I18n.t("#{@copy_key}_question")
      ].compact_blank.join("\n\n")
    end

    # Omitted rather than printed empty when the phase has no categories at all:
    # a "Category:" line with nothing after it reads as a bug.
    def category_line
      category = Whatsapp::DraftCategory.label_for(draft_resource)

      return if category.blank?

      I18n.t("whatsapp.bot.proposal.category_line", category: category)
    end

    def plain_description
      ActionController::Base.helpers
        .strip_tags(draft_resource.description.to_s)
        .squish
        .truncate(DESCRIPTION_PREVIEW_LENGTH)
    end

    def buttons
      [
        Whatsapp::FlowActions.button(
          action: :draft_publish, label_key: "whatsapp.bot.buttons.draft_publish"
        ),
        Whatsapp::FlowActions.button(
          action: :draft_revise, label_key: "whatsapp.bot.buttons.draft_revise"
        )
      ]
    end
end
