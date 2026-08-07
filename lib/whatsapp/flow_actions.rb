module Whatsapp::FlowActions
  # Every quick-reply pill the flow catalog sends carries an id of one shape:
  # what to do, and optionally which record or setting to do it to. One shape
  # means one parser, so a pill tapped a week later is re-resolved rather than
  # trusted.
  #
  #   whatsapp_flow_link_yes                   no parameter
  #   whatsapp_flow_support-4821               proposal 4821
  #   whatsapp_flow_notify_toggle-new_supports the notification type
  #
  # The separator is a dash rather than an underscore because the action itself
  # contains underscores; a single delimiter that cannot occur inside the action
  # is what keeps the pattern unambiguous.
  PREFIX = "whatsapp_flow_".freeze
  SEPARATOR = "-".freeze

  ONBOARDING_ACTIONS = %i[
    link_yes
    link_later
    link_retry
    link_switch
    unlink_confirm
    unlink_cancel
  ].freeze

  DISCOVERY_ACTIONS = %i[discover discover_public dismiss view_projekt].freeze

  PROPOSAL_ACTIONS = %i[
    submit_proposal
    idea_start
    category
    sentiment
    draft_publish
    draft_revise
    image_upload
    image_generate
    image_skip
    resume
    restart
  ].freeze

  ENGAGEMENT_ACTIONS = %i[support my_contributions].freeze

  NOTIFICATION_ACTIONS = %i[notify_toggle notifications_done].freeze

  ACTIONS = (
    ONBOARDING_ACTIONS + DISCOVERY_ACTIONS + PROPOSAL_ACTIONS +
      ENGAGEMENT_ACTIONS + NOTIFICATION_ACTIONS
  ).freeze

  ID_PATTERN =
    /\A#{PREFIX}(?<action>[a-z_]+)(?:#{SEPARATOR}(?<param>[a-z0-9_]+))?\z/

  # Words a citizen may type instead of tapping. Both languages are recognised
  # regardless of the citizen's locale, for the same reason the command menu is:
  # someone who saw the pill in German keeps typing "hilfe" after switching
  # their phone to English.
  HELP_KEYWORDS = ["help", "hilfe"].freeze
  DISCOVERY_KEYWORDS = ["projects", "projekte"].freeze
  NOTIFICATION_KEYWORDS = ["notifications", "benachrichtigungen"].freeze
  UNLINK_KEYWORDS = ["unlink account", "konto trennen", "verknüpfung aufheben"].freeze

  # Aborting a draft, not unsubscribing. Held apart from Whatsapp::OPT_OUT
  # keywords deliberately: the catalog uses the same word for both, and the
  # difference is whether a flow is open. See ProcessInboundMessageService.
  ABORT_KEYWORDS = ["stop", "stopp", "abbrechen", "cancel"].freeze

  module_function

  def id_for(action:, param: nil)
    return "#{PREFIX}#{action}" if param.blank?

    "#{PREFIX}#{action}#{SEPARATOR}#{param}"
  end

  # Returns nil for anything that is not one of ours, including a pill from an
  # older deploy whose action no longer exists.
  def parse(reply_id)
    match = ID_PATTERN.match(reply_id.to_s)

    return if match.blank?

    action = match[:action].to_sym

    return if !ACTIONS.include?(action)

    { action: action, param: match[:param] }
  end

  def button(action:, label_key:, param: nil)
    { id: id_for(action: action, param: param), title: I18n.t(label_key) }
  end
end
