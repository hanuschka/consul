class Whatsapp::MenuActionService < ApplicationService
  # The one place a navigation action is turned into a reply. A tapped row and
  # the assistant's open_menu_action tool both arrive here, so the two entry
  # points cannot answer the same action differently — and adding an action
  # means adding it here once rather than in a handler and a tool.
  #
  # Returns false for an action whose record has gone, which is how the caller
  # knows to fall back rather than leave the citizen with silence.
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
      when :polls then Whatsapp::Steps::ListPollsService.call(conversation: @conversation)
      when :projekts then Whatsapp::Steps::ListProjektsService.call(conversation: @conversation)
      when :events then Whatsapp::Steps::ListEventsService.call(conversation: @conversation)
      when :milestones then Whatsapp::Steps::ListMilestonesService.call(conversation: @conversation)
      when :results then Whatsapp::Steps::ListResultsService.call(conversation: @conversation)
      when :contributions then Whatsapp::Steps::ListContributionsService.call(conversation: @conversation)
      when :notifications then Whatsapp::Steps::NotificationSettingsService.call(conversation: @conversation)
      when :help then send_page(:help)
      when :contact then send_page(:contact)
      else return false
      end

      true
    end

    def projekt_action
      return false if projekt.blank?

      case @action
      when :card then step(Whatsapp::Steps::SendProjektCardService)
      when :menu then step(Whatsapp::Steps::ProjektMenuService)
      when :phases then step(Whatsapp::Steps::ListPhasesService)
      when :contributions then step(Whatsapp::Steps::ListProjektContributionsService)
      when :events then step(Whatsapp::Steps::ListEventsService)
      when :milestones then step(Whatsapp::Steps::ListMilestonesService)
      when :results then step(Whatsapp::Steps::ListResultsService)
      when :follow then step(Whatsapp::Steps::ToggleProjektFollowService)
      when :page then step(Whatsapp::Steps::SendProjektPageService)
      else return false
      end

      true
    end

    def phase_action
      return false if projekt_phase.blank?

      case @action
      when :menu then Whatsapp::Steps::PhaseMenuService.call(
        conversation: @conversation, projekt_phase: projekt_phase
      )
      when :participate then Whatsapp::Steps::StartPhaseParticipationService.call(
        conversation: @conversation, projekt_phase: projekt_phase
      )
      when :contributions then Whatsapp::Steps::ListPhaseContributionsService.call(
        conversation: @conversation, projekt_phase: projekt_phase
      )
      when :results then Whatsapp::Steps::SendPhaseResultsService.call(
        conversation: @conversation, projekt_phase: projekt_phase
      )
      when :page then Whatsapp::Steps::SendPhasePageService.call(
        conversation: @conversation, projekt_phase: projekt_phase
      )
      else return false
      end

      true
    end

    def step(service)
      service.call(conversation: @conversation, projekt: projekt)
    end

    # The row only says "submit something"; which phase, and whether one has to
    # be chosen at all, is the question NextStepService already answers.
    def start_creation
      @conversation.reset_flow!

      Whatsapp::NextStepService.call(conversation: @conversation)
    end

    def send_page(page_key)
      Whatsapp::Steps::SendStaticPageService.call(conversation: @conversation, page_key: page_key)
    end

    # Resolved through the browsable list rather than by id: a row can be tapped
    # weeks after it was sent, and a projekt withdrawn in between must stop being
    # reachable through the old message.
    def projekt
      return @projekt if defined?(@projekt)

      @projekt = WhatsappBrowsableProjektsQuery.call.find { |candidate| candidate.id == @record_id }
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
          .joins(projekt: :page)
          .where(site_customization_pages: { status: "published" })
          .where(projekt_id: Projekt.activated.select(:id))
          .includes(projekt: :page)
          .find_by(id: @record_id)
    end
end
