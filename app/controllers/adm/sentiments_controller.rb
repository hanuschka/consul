module Adm
  class SentimentsController < Adm::BaseController
    before_action :set_projekt_phase
    before_action :set_sentiment, only: %i[edit update destroy]

    def new
      @sentiment = @projekt_phase.sentiments.new
      authorize [:adm, @sentiment]

      @breadcrumbs = breadcrumbs_for_action(t(".title"))
    end

    def create
      @sentiment = @projekt_phase.sentiments.new(sentiment_params)
      authorize [:adm, @sentiment]

      if @sentiment.save
        redirect_to sentiments_adm_projekt_phase_path(@projekt_phase), notice: t(".success")
      else
        @breadcrumbs = breadcrumbs_for_action(t("adm.sentiments.new.title"))
        render :new
      end
    end

    def edit
      authorize [:adm, @sentiment]

      @breadcrumbs = breadcrumbs_for_action(t(".title"))
    end

    def update
      authorize [:adm, @sentiment]

      if @sentiment.update(sentiment_params)
        redirect_to sentiments_adm_projekt_phase_path(@projekt_phase), notice: t(".success")
      else
        @breadcrumbs = breadcrumbs_for_action(t("adm.sentiments.edit.title"))
        render :edit
      end
    end

    def destroy
      authorize [:adm, @sentiment]

      @sentiment.destroy!
      redirect_to sentiments_adm_projekt_phase_path(@projekt_phase), notice: t(".success")
    end

    private

      def set_projekt_phase
        @projekt_phase = ProjektPhase.find(params[:projekt_phase_id])
      end

      def set_sentiment
        @sentiment = Sentiment.find(params[:id])
      end

      def sentiment_params
        params.require(:sentiment).permit(:name, :color)
      end

      def breadcrumbs_for_action(action_title)
        [
          { name: t("adm.menu.items.projekts"), url: adm_projekts_path },
          { name: @projekt_phase.projekt.name, url: details_adm_projekt_path(@projekt_phase.projekt) },
          { name: @projekt_phase.title },
          { name: t("adm.projekt_phases.sentiments.title"), url: sentiments_adm_projekt_phase_path(@projekt_phase) },
          { name: action_title }
        ]
      end
  end
end
