module Whatsapp::Archive::MenuActions
  # Every navigation row and every navigation button the bot sends carries an id
  # of one shape: what it acts on, which record, and what to do. One shape means
  # one parser and one dispatcher, so the portal menu, a projekt's menu and a
  # phase's menu can never drift into answering the same tap differently.
  #
  #   whatsapp_a_m_0_create        the portal menu, no record
  #   whatsapp_a_p_219_phases      projekt 219
  #   whatsapp_a_f_484_participate projekt phase 484
  PREFIX = "whatsapp_a_".freeze

  SCOPE_CODES = {
    portal: "m",
    projekt: "p",
    phase: "f"
  }.freeze

  # Ordered: the sections and the rows inside them reach the citizen in this
  # order, and the ten-row budget is spent top down.
  PORTAL_SECTIONS = {
    participate: %i[create polls],
    discover: %i[projekts events milestones results],
    account: %i[contributions notifications],
    service: %i[help contact]
  }.freeze

  # No "open the page" row: the projekt menu prints the projekt's link in its
  # own body, so the row only repeated what the citizen is already looking at.
  # The phase menu keeps its row — its body carries no phase link.
  PROJEKT_SECTIONS = {
    participate: %i[phases],
    discover: %i[contributions events milestones results],
    account: %i[follow]
  }.freeze

  PHASE_SECTIONS = {
    participate: %i[participate],
    discover: %i[contributions results],
    service: %i[page]
  }.freeze

  SECTIONS_BY_SCOPE = {
    portal: PORTAL_SECTIONS,
    projekt: PROJEKT_SECTIONS,
    phase: PHASE_SECTIONS
  }.freeze

  # Actions that are reachable but are not rows of the menu they belong to: a
  # projekt menu listing "projekt menu" leads nowhere. :card is what a projekt
  # row in a list opens; :menu is what the card's own button opens.
  ACTIONS_BY_SCOPE = {
    portal: PORTAL_SECTIONS.values.flatten.freeze,
    projekt: (PROJEKT_SECTIONS.values.flatten + %i[menu card]).freeze,
    phase: (PHASE_SECTIONS.values.flatten + %i[menu]).freeze
  }.freeze

  ID_PATTERN = /\A#{PREFIX}(?<scope>[mpf])_(?<record_id>\d+)_(?<action>[a-z_]+)\z/.freeze

  # The words the number's command menu advertises. WhatsApp sends a tapped
  # command as ordinary text, so without this they would reach the assistant and
  # cost a completion to re-derive what the word already says.
  #
  # Both languages are recognised regardless of the citizen's locale: someone
  # who saw the menu in German keeps typing "hilfe" after switching their phone
  # to English. :menu means the portal menu itself, which is not a row action.
  COMMAND_ACTIONS = {
    "menu" => :menu,
    "hilfe" => :help,
    "help" => :help,
    "projekte" => :projekts,
    "projects" => :projekts
  }.freeze

  module_function

  def command_action_from(text)
    COMMAND_ACTIONS[text.to_s.strip.downcase.delete_prefix("/")]
  end

  def id_for(scope:, action:, record_id: 0)
    "#{PREFIX}#{SCOPE_CODES.fetch(scope)}_#{record_id}_#{action}"
  end

  # Returns nil for anything that is not one of ours, including a row id from an
  # older deploy whose action no longer exists.
  def parse(row_id)
    match = ID_PATTERN.match(row_id.to_s)

    return if match.blank?

    scope = SCOPE_CODES.key(match[:scope])
    action = match[:action].to_sym

    return if !ACTIONS_BY_SCOPE.fetch(scope, []).include?(action)

    { scope: scope, record_id: match[:record_id].to_i, action: action }
  end

  def sections_for(scope)
    SECTIONS_BY_SCOPE[scope]
  end

  # Reading the portal needs no account; taking part in it or changing one's own
  # settings does. Split here rather than at the call site so both the tapped
  # row and the assistant tool are held to the same line.
  ACCOUNT_ACTIONS = %i[create participate contributions notifications follow].freeze

  def needs_account?(action)
    ACCOUNT_ACTIONS.include?(action)
  end
end
