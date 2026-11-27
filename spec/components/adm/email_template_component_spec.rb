require "rails_helper"

describe Adm::EmailTemplateComponent, type: :component, controller: Adm::BaseController do
  def template_for(key)
    mailer_class, mailer_action = key.split("#")
    SiteCustomization::EmailTemplate.new(id: 1, mailer_class: mailer_class, mailer_action: mailer_action)
  end

  def default_preview(template)
    render_inline(described_class.new(template))
    page.all(".adm-email-template-preview", visible: :all).map(&:native).map(&:inner_html).join
  end

  it "only shows variables the template offers in the default preview" do
    SiteCustomization::EmailTemplate::EMAIL_TEMPLATES.each_key do |key|
      template = template_for(key)
      preview = default_preview(template)

      expect(preview.scan(/\{\{ (\w+) \}\}/).flatten - template.registered_variables).to be_empty, key
      expect(preview).not_to match(/\[\w[\w.()]*\]/), key
    end
  end

  it "shows the link targets of the default reply email as variables" do
    preview = default_preview(template_for("Mailer#reply"))

    expect(preview).to include("{{ recipient_greeting }},")
    expect(preview).to include("{{ comment_url }}")
  end

  it "shows a single greeting in the officer emails" do
    %w[DeficiencyReportMailer#notify_officer NotificationServiceMailer#new_comments_for_deficiency_report].each do |key|
      preview = default_preview(template_for(key))

      expect(preview).to include("{{ recipient_greeting }},"), key
      expect(preview).not_to include(I18n.t("mailers.shared.greeting_without_name")), key
    end
  end
end
