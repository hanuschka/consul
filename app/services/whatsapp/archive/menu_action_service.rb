class Whatsapp::Archive::MenuActionService < ApplicationService
  # The one place a navigation action is turned into a reply. A tapped row and
  # the assistant's open_menu_action tool both arrive here, so the two entry
  # points cannot answer the same action differently — and adding an action
  # means adding it here once rather than in a handler and a tool.
  #
  # Returns false for an action whose record has gone, which is how the caller
  # knows to fall back rather than leave the citizen with silence.
  # A projekt row and a phase row each reach one step service with one argument,
  # so the routes are data: adding an action is a line here, not an arm in a
  # case that already reads as nine copies of the same call.
  PROJEKT_STEPS = {
    card: ::Whatsapp::Archive::SendProjektCardService,
    menu: ::Whatsapp::Archive::ProjektMenuService,
    phases: ::Whatsapp::Archive::ListPhasesService,
    contributions: ::Whatsapp::Archive::ListProjektContributionsService,
    events: ::Whatsapp::Archive::ListEventsService,
    milestones: ::Whatsapp::Archive::ListMilestonesService,
    results: ::Whatsapp::Archive::ListResultsService,
    follow: ::Whatsapp::Archive::ToggleProjektFollowService
  }.freeze

  PHASE_STEPS = {
    menu: ::Whatsapp::Archive::PhaseMenuService,
    participate: ::Whatsapp::Archive::StartPhaseParticipationService,
    contributions: ::Whatsapp::Archive::ListPhaseContributionsService,
    results: ::Whatsapp::Archive::SendPhaseResultsService,
    page: ::Whatsapp::Archive::SendPhasePageService
  }.freeze

  def initialize(conversation:, scope:, action:, record_id: 0)
    @conversation = conversation
    @scope = scope
    @action = action
    @record_id = record_id
  end

  def call
    case @scope
    when :portal then portal_action
    when :projekt then projekt_action
    when :phase then phase_action
    else false
    end
  end

  private

    def portal_action
      case @action
      when :create then start_creation
      when :polls then ::Whatsapp::Archive::ListPollsService.call(conversation: @conversation)
      when :projekts then ::Whatsapp::Archive::ListProjektsService.call(conversation: @conversation)
      when :events then ::Whatsapp::Archive::ListEventsService.call(conversation: @conversation)
      when :milestones then ::Whatsapp::Archive::ListMilestonesService.call(conversation: @conversation)
      when :results then ::Whatsapp::Archive::ListResultsService.call(conversation: @conversation)
      when :contributions then ::Whatsapp::Archive::ListContributionsService.call(conversation: @conversation)
      when :notifications then ::Whatsapp::Archive::NotificationSettingsService.call(conversation: @conversation)
      when :help then ::Whatsapp::Flows::HelpService.call(conversation: @conversation)
      when :contact then send_page(:contact)
      else return false
      end

      true
    end

    def projekt_action
      service = PROJEKT_STEPS[@action]

      return false if service.blank? || projekt.blank?

      service.call(conversation: @conversation, projekt: projekt)

      true
    end

    def phase_action
      service = PHASE_STEPS[@action]

      return false if service.blank? || projekt_phase.blank?

      service.call(conversation: @conversation, projekt_phase: projekt_phase)

      true
    end

    # The row only says "submit something"; which phase, and whether one has to
    # be chosen at all, is the question NextStepService already answers.
    def start_creation
      @conversation.reset_flow!

      ::Whatsapp::Archive::NextStepService.call(conversation: @conversation)
    end

    def send_page(page_key)
      ::Whatsapp::Archive::SendStaticPageService.call(conversation: @conversation, page_key: page_key)
    end

    # Resolved through the browsable list rather than by id: a row can be tapped
    # weeks after it was sent, and a projekt withdrawn in between must stop being
    # reachable through the old message.
    def projekt
      return @projekt if defined?(@projekt)

      @projekt = Whatsapp::BrowsableProjektsQuery.call.find { |candidate| candidate.id == @record_id }
    end

    # Restricted to phases of a projekt the portal itself shows. Without the
    # projekt check an id — tapped from an old row, or supplied by the model
    # through open_projekt_phase — would open a phase of a deactivated or
    # unpublished projekt that no visitor can reach on the website.
    def projekt_phase
      return @projekt_phase if defined?(@projekt_phase)

      @projekt_phase =
        ProjektPhase
          .where(hidden_at: nil, active: true)
          .of_publicly_visible_projekt
          .includes(projekt: :page)
          .find_by(id: @record_id)
    end
end
