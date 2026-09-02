class Files::ResourceAssetComponent < ApplicationComponent
  private

    def resource_name(record)
      return nil if record.blank?

      name =
        case record
        when Projekt
          record.page&.title.presence || record.name
        when ProjektPhase
          record.phase_tab_name.presence || record.name
        when ProjektArgument
          record.name
        when Milestone
          record.title.presence || resource_name(record.milestoneable)
        when Newsletter
          record.title.presence || record.subject
        else
          fallback_resource_name(record)
        end

      name.presence
    end

    def owning_resource(record)
      return nil if record.blank?

      case record
      when Milestone
        record.milestoneable
      when Widget::Card
        record.cardable
      else
        record
      end
    end

    def owning_resource_type_label(record)
      resource = owning_resource(record)
      return nil if resource.blank?

      resource.model_name.human
    end

    def resource_projekt(record)
      resource = owning_resource(record)
      return nil if resource.blank?

      case resource
      when Projekt
        resource
      when ProjektPhase
        resource.projekt
      when ProjektArgument
        resource.projekt_phase&.projekt
      when Proposal, Debate, Poll, Budget::Investment
        resource.projekt
      else
        nil
      end
    end

    def resource_url(record)
      return nil if record.blank?

      case record
      when Projekt
        projekt_resource_url(record)
      when ProjektPhase
        phase_resource_url(record)
      when ProjektArgument
        phase_resource_url(record.projekt_phase)
      when Milestone
        resource_url(record.milestoneable)
      when Widget::Card
        card_resource_url(record)
      when Newsletter
        helpers.edit_adm_newsletter_path(record)
      when SiteCustomization::Page
        helpers.page_path(record.slug)
      when Proposal
        helpers.proposal_path(record)
      when Debate
        helpers.debate_path(record)
      when Poll
        helpers.poll_path(record)
      when DeficiencyReport
        helpers.deficiency_report_path(record)
      when Budget::Investment
        helpers.budget_investment_path(record.budget_id, record)
      else
        fallback_resource_url(record)
      end
    end

    def projekt_resource_url(projekt)
      page = projekt.page
      return nil if page.blank?

      helpers.page_path(page.slug)
    end

    def phase_resource_url(phase)
      return nil if phase.blank?

      page = phase.projekt&.page
      return nil if page.blank?

      helpers.page_path(page.slug, projekt_phase_id: phase.id, anchor: "projekt-footer")
    end

    def card_resource_url(card)
      cardable = card.cardable

      if cardable.is_a?(SiteCustomization::Page)
        return helpers.page_path(cardable.slug)
      end

      return helpers.root_path if cardable.blank?

      nil
    end

    def fallback_resource_name(record)
      if record.respond_to?(:title) && record.title.present?
        record.title
      elsif record.respond_to?(:name) && record.name.present?
        record.name
      end
    end

    def fallback_resource_url(record)
      helpers.polymorphic_path(record)
    rescue NoMethodError, ActionController::UrlGenerationError
      nil
    end
end
