class IdeaMailer < ApplicationMailer
  helper TextWithLinksHelper

  def notify_officer(idea, officer)
    @idea = idea
    @idea_officer = officer
    return if @idea.blank? || @idea_officer.blank?

    subject = t("custom.ideas.mailers.notify_officer.subject",
                identifier: "#{@idea.id}: #{@idea.title.first(50)}")
    @email_to = @idea_officer.email

    with_user(@idea_officer.user) do
      mail(to: @email_to, subject: subject)
    end
  end

  private

    def with_user(user)
      I18n.with_locale(user.locale) do
        yield
      end
    end
end
