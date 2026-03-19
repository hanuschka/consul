class Adm::EmailTemplatesController < Adm::BaseController
  before_action :find_email_template

  def update
    authorize @email_template, policy_class: Adm::SiteCustomization::EmailTemplatePolicy

    if @email_template.update(email_template_params)
      flash.now[:success] = t("adm.attribute.update.success")
    end

    render_component
  end

  def send_test
    authorize @email_template, :update?, policy_class: Adm::SiteCustomization::EmailTemplatePolicy

    sample_variables = @email_template.registered_variables.index_with { |v| "[#{v}]" }

    Mailer.customizable_test_email(
      current_user.email,
      @email_template.render_subject(sample_variables) || @email_template.template_key,
      @email_template.render_body(sample_variables) || ""
    ).deliver_later

    flash.now[:success] = t("adm.email_templates.send_test.success", email: current_user.email)

    render_component
  end

  private

    def render_component
      render turbo_stream: turbo_stream.replace(
        helpers.dom_id(@email_template),
        Adm::EmailTemplateComponent.new(@email_template)
      )
    end

    def find_email_template
      @email_template = SiteCustomization::EmailTemplate.find(params[:id])
    end

    def email_template_params
      params.require(:site_customization_email_template).permit(:subject, :body)
    end
end
