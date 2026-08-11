class Adm::DeficiencyReports::IntakeChannelsController < Adm::DeficiencyReports::BaseController
  include Translatable

  def index
    @intake_channels = policy_scope(DeficiencyReport::IntakeChannel,
      policy_scope_class: Adm::DeficiencyReports::IntakeChannelPolicy::Scope)

    @breadcrumbs = [{ name: t("adm.deficiency_reports.menu.items.intake_channels"), icon: "call_received" }]
  end

  def new
    @intake_channel = DeficiencyReport::IntakeChannel.new
    authorize @intake_channel, policy_class: Adm::DeficiencyReports::IntakeChannelPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def edit
    @intake_channel = DeficiencyReport::IntakeChannel.find(params[:id])
    authorize @intake_channel, policy_class: Adm::DeficiencyReports::IntakeChannelPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def create
    @intake_channel = DeficiencyReport::IntakeChannel.new(intake_channel_params)
    authorize @intake_channel, policy_class: Adm::DeficiencyReports::IntakeChannelPolicy

    if @intake_channel.save
      redirect_to adm_deficiency_reports_intake_channels_path, notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.deficiency_reports.intake_channels.new.title"))
      render :new
    end
  end

  def update
    @intake_channel = DeficiencyReport::IntakeChannel.find(params[:id])
    authorize @intake_channel, policy_class: Adm::DeficiencyReports::IntakeChannelPolicy

    if @intake_channel.update(intake_channel_params)
      redirect_to adm_deficiency_reports_intake_channels_path, notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.deficiency_reports.intake_channels.edit.title"))
      render :edit
    end
  end

  def destroy
    @intake_channel = DeficiencyReport::IntakeChannel.find(params[:id])
    authorize @intake_channel, policy_class: Adm::DeficiencyReports::IntakeChannelPolicy

    if @intake_channel.safe_to_destroy?
      @intake_channel.destroy!
      redirect_to adm_deficiency_reports_intake_channels_path, notice: t(".success")
    else
      redirect_to adm_deficiency_reports_intake_channels_path, alert: t(".cannot_destroy")
    end
  end

  def order_intake_channels
    authorize DeficiencyReport::IntakeChannel, :update?,
      policy_class: Adm::DeficiencyReports::IntakeChannelPolicy
    DeficiencyReport::IntakeChannel.order_intake_channels(params[:tree].map { |item| item[:id] })
    head :ok
  end

  private

    def breadcrumbs_for_action(action_title)
      [
        { name: t("adm.deficiency_reports.intake_channels.index.title"),
          url: adm_deficiency_reports_intake_channels_path, icon: "call_received" },
        { name: action_title }
      ]
    end

    def intake_channel_params
      params.require(:deficiency_report_intake_channel).permit(:name, :default)
    end
end
