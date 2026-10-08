class Adm::MunicipalPlans::TopicsController < Adm::MunicipalPlans::BaseController
  def index
    authorize MunicipalPlan::Topic, :index?, policy_class: Adm::MunicipalPlans::TopicPolicy

    @topics = policy_scope(
      MunicipalPlan::Topic,
      policy_scope_class: Adm::MunicipalPlans::TopicPolicy::Scope
    )

    @breadcrumbs = [{ name: t("adm.municipal_plans.menu.items.topics"), icon: "category" }]
  end

  def new
    @topic = MunicipalPlan::Topic.new
    authorize @topic, policy_class: Adm::MunicipalPlans::TopicPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def edit
    @topic = MunicipalPlan::Topic.find(params[:id])
    authorize @topic, policy_class: Adm::MunicipalPlans::TopicPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def create
    @topic = MunicipalPlan::Topic.new(topic_params)
    authorize @topic, policy_class: Adm::MunicipalPlans::TopicPolicy

    if @topic.save
      redirect_to adm_municipal_plans_topics_path, notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.municipal_plans.topics.new.title"))
      render :new
    end
  end

  def update
    @topic = MunicipalPlan::Topic.find(params[:id])
    authorize @topic, policy_class: Adm::MunicipalPlans::TopicPolicy

    if @topic.update(topic_params)
      redirect_to adm_municipal_plans_topics_path, notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.municipal_plans.topics.edit.title"))
      render :edit
    end
  end

  def destroy
    @topic = MunicipalPlan::Topic.find(params[:id])
    authorize @topic, policy_class: Adm::MunicipalPlans::TopicPolicy

    if @topic.destroy
      redirect_to adm_municipal_plans_topics_path, notice: t(".success")
    else
      redirect_to adm_municipal_plans_topics_path, alert: t(".cannot_destroy")
    end
  end

  def order_topics
    authorize MunicipalPlan::Topic, :update?, policy_class: Adm::MunicipalPlans::TopicPolicy

    MunicipalPlan::Topic.order_topics(params[:tree].map { |item| item[:id] })
    head :ok
  end

  private

    def breadcrumbs_for_action(action_title)
      [
        { name: t("adm.municipal_plans.topics.index.title"),
          url: adm_municipal_plans_topics_path, icon: "category" },
        { name: action_title }
      ]
    end

    def topic_params
      params.require(:municipal_plan_topic).permit(:name)
    end
end
