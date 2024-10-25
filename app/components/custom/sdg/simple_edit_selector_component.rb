class SDG::SimpleEditSelectorComponent < ApplicationComponent
  attr_reader :f

  def initialize(form)
    @f = form
  end

  def render?
    SDG::ProcessEnabled.new(f.object).enabled?
  end

  private

  def goals
    SDG::Goal.order(:code)
  end

  def goal_field(checkbox_form)
    goal = checkbox_form.object

    checkbox_form.check_box(data: { code: goal.code }) +
      checkbox_form.label(data: { 'sdg-goal-id': goal.id }, title: goal.title) { render(SDG::Goals::IconComponent.new(goal)) }
  end

  def text_for(goal_or_target)
    if goal_or_target.class.name == "SDG::Goal"
      t("sdg.related_list_selector.goal_identifier", code: goal_or_target.code)
    else
      goal_or_target.code
    end
  end

  def relatable_name
    f.object.model_name.human.downcase
  end

end
