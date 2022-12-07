require_dependency Rails.root.join("app", "components", "application_component").to_s

class ApplicationComponent < ViewComponent::Base
  delegate :current_path_with_query_params, to: :helpers

  def set_comment_flags(comments)
    @comment_flags = helpers.current_user ? helpers.current_user.comment_flags(comments) : {}
    @comment_flags
  end

  def current_path_with_query_params_merged_subarrays(new_query_parameters)
    params = request.query_parameters.dup

    new_query_parameters.stringify_keys.each do |key, value|
      selected_values = params[key].present? ? params[key].split(",") : []

      if selected_values.include?(value)
        selected_values.delete(value)
      else
        selected_values.push(value)
      end

      params[key] = selected_values.join(",")
    end

    params = params.delete_if { |key, value| value.blank? }

    url_for(params.merge(only_path: true))
  end

  def path_for_resource_with_params(resource, params)
    case resource
    when Debate
      debates_path(params)
    when Proposal
      proposals_path(params)
    when Poll
      polls_path(params)
    when Budget::Investment
      budget_investments_path(resource, params)
    when Legislation::Proposal
      legislation_process_proposals_path(resource, params)
    when Projekt
      projekts_path(params)
    else
      "#"
    end
  end
end
