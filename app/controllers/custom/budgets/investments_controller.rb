require_dependency Rails.root.join("app", "controllers", "budgets", "investments_controller").to_s

module Budgets
  class InvestmentsController < ApplicationController
    include GuestUsers
    include OnBehalfOfAccountLinking
    include ::SimilarContributionsCheck

    respond_to :js, only: [:stats]

    skip_load_and_authorize_resource only: [:similar_contributions_status, :publish_draft]
    skip_authorization_check only: [:similar_contributions_status, :publish_draft]
    before_action :load_own_similarity_draft,
                  only: [:similar_contributions_status, :publish_draft]

    def new
      if @budget.projekt_phase.permission_problem(current_user, location: :new_button_component)
        redirect_to page_path(@budget.projekt.page.slug,
                              projekt_phase_id: @budget.projekt_phase.id,
                              anchor: "filter-subnav")
      end

      if @budget.projekt.present?
        resolve_landing_page_for_projekt(@budget.projekt)
      end
    end

    def create
      @investment.author = current_user
      @investment.heading = @budget.heading

      if @investment.invalid? || !link_on_behalf_of_account(@investment)
        return respond_with_invalid_investment
      end

      if similar_contributions_check_requested?(@budget.projekt_phase)
        return respond_with_invalid_investment if !start_similar_contributions_check(@investment)

        return respond_with_started_check
      end

      return respond_with_invalid_investment if !@investment.save

      publish_checked_investment

      respond_with_published_investment
    end

    def similar_contributions_status
      render json: similar_contributions_status_payload(@investment)
    end

    def publish_draft
      publish_checked_investment

      respond_with_published_investment
    end

    def update
      if @investment.update(investment_params)
        redirect_to budget_investment_path(@budget, @investment),
                    notice: t("flash.actions.update.budget_investment")
      else
        if @budget.projekt.present?
          resolve_landing_page_for_projekt(@budget.projekt)
        end

        render "edit"
      end
    end

    def flag
      flag = Flag.flag(current_user, @investment)
      Flags::NotifyModerationJob.perform_later(flag.id) if flag
      @investment.update!(ignored_flag_at: nil)

      redirect_to @investment
    end

    def unflag
      Flag.unflag(current_user, @investment)
      redirect_to @investment
    end

    def read_stats
      authorize! :read_stats, @investment
    end

    private

      # The draft default scope hides unpublished contributions, so the citizen's
      # own in-flight draft has to be looked up past it.
      def load_own_similarity_draft
        @investment = @budget.investments
          .unscope(where: :draft)
          .where(author: current_user)
          .find(params[:id])
      end

      def publish_checked_investment
        @investment.update!(draft: false, published_at: Time.current)

        Mailer.budget_investment_created(@investment).deliver_later
        NotificationServices::NewBudgetInvestmentNotifier.call(@investment.id) #custom
      end

      def respond_with_invalid_investment
        respond_to do |format|
          format.html { render_new_form }
          format.json do
            render json: similar_contributions_invalid_payload(@investment),
                   status: :unprocessable_entity
          end
        end
      end

      def respond_with_started_check
        respond_to do |format|
          format.html { render_new_form }
          format.json { render json: similar_contributions_check_started_payload(@investment) }
        end
      end

      def respond_with_published_investment
        respond_to do |format|
          format.html do
            redirect_to budget_investment_path(@budget, @investment),
                        notice: t("flash.actions.create.budget_investment")
          end

          format.json do
            flash[:notice] = t("flash.actions.create.budget_investment")

            render json: {
              status: "published",
              redirect_url: budget_investment_path(@budget, @investment)
            }
          end
        end
      end

      def render_new_form
        if @budget.projekt.present?
          resolve_landing_page_for_projekt(@budget.projekt)
        end

        render :new
      end

      def investment_params
        attributes = [:heading_id, :tag_list, :organization_name, :location, :on_behalf_of,
                      :on_behalf_of_company_name, :on_behalf_of_email, :video_url,
                      :related_sdg_list, :implementation_performer, :implementation_contribution, :user_cost_estimate,
                      :terms_of_service, :terms_data_storage, :terms_data_protection, :terms_general, :resource_terms,
                      :sentiment_id,
                      projekt_label_ids: [],
                      image_attributes: image_attributes,
                      documents_attributes: document_attributes,
                      map_location_attributes: map_location_attributes]
        params.require(:budget_investment).permit(attributes, translation_params(Budget::Investment))
      end

  end
end
