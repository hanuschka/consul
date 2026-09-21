class Adm::MunicipalPlans::MenuComponent < Adm::BaseMenuComponent
  def aria_label
    t("adm.municipal_plans.menu.aria_label")
  end

  def menu_items
    [officers_item, officer_groups_item, topics_item].compact
  end

  private

    def officers_item
      return unless Adm::MunicipalPlans::OfficerPolicy.new(current_user, nil).index?

      {
        label: t("adm.municipal_plans.menu.items.officers"),
        icon: "badge",
        path: adm_municipal_plans_officers_path
      }
    end

    def officer_groups_item
      return unless Adm::MunicipalPlans::OfficerGroupPolicy.new(current_user, nil).index?

      {
        label: t("adm.municipal_plans.menu.items.officer_groups"),
        icon: "groups",
        path: adm_municipal_plans_officer_groups_path
      }
    end

    def topics_item
      return unless Adm::MunicipalPlans::TopicPolicy.new(current_user, nil).index?

      {
        label: t("adm.municipal_plans.menu.items.topics"),
        icon: "category",
        path: adm_municipal_plans_topics_path
      }
    end
end
