class Ai::Tools::WhatsappAiAssistant::OpenMenuAction < Ai::Tools::WhatsappAiAssistant::BaseTool
  PORTAL_ACTIONS = ::Whatsapp::MenuActions::ACTIONS_BY_SCOPE.fetch(:portal).map(&:to_s).freeze

  description "Takes the citizen straight to one of the portal's destinations, exactly as tapping " \
              "that row in the menu would. Use it whenever they say what they want instead of " \
              "sending them to the menu to find it themselves. " \
              "create: start submitting an idea. " \
              "polls: the running votes. " \
              "projekts: the running projekts. " \
              "events: upcoming dates. " \
              "milestones: what has progressed. " \
              "results: evaluations of finished phases. " \
              "contributions: what this citizen submitted. " \
              "notifications: their message and follow settings. " \
              "help: how the portal works. " \
              "contact: reaching the team. " \
              "This sends the message itself — do not write one as well."

  params do
    string :action, description: "One of: #{PORTAL_ACTIONS.join(', ')}"
  end

  def execute(action:)
    return unknown_action_error if !PORTAL_ACTIONS.include?(action.to_s)

    handled = ::Whatsapp::MenuActionService.call(
      conversation: conversation,
      scope: :portal,
      action: action.to_s.to_sym
    )

    return unknown_action_error if !handled

    halt("Opened #{action} for the citizen.")
  end

  private

    def unknown_action_error
      { error: "No such destination. Allowed: #{PORTAL_ACTIONS.join(', ')}." }
    end
end
