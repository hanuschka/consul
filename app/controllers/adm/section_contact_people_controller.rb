module Adm
  class SectionContactPeopleController < Adm::BaseController
    before_action :load_section_contact_person, only: [:edit, :update, :destroy]

    SECTION_REDIRECTS = {
      "projekts"            => :adm_projekts_settings_path,
      "ideas"               => :adm_ideas_settings_path,
      "deficiency_reports"  => :adm_deficiency_reports_settings_path,
      "landing_pages"       => :adm_landing_pages_settings_path,
      "moderation"          => :adm_moderation_settings_path,
      "valuation"           => :adm_valuation_settings_path
    }.freeze

    helper_method :back_url

    def new
      @section_contact_person = SectionContactPerson.new(section: params[:section])
      authorize [:adm, @section_contact_person]
      @breadcrumbs = form_breadcrumbs
    end

    def create
      @section_contact_person = SectionContactPerson.new(section_contact_person_params)
      authorize [:adm, @section_contact_person]

      if @section_contact_person.save
        redirect_to redirect_path_for(@section_contact_person.section), notice: t(".success")
      else
        @breadcrumbs = form_breadcrumbs
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @breadcrumbs = form_breadcrumbs
    end

    def update
      if @section_contact_person.update(section_contact_person_params)
        redirect_to redirect_path_for(@section_contact_person.section), notice: t(".success")
      else
        @breadcrumbs = form_breadcrumbs
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @section_contact_person.destroy!
      redirect_to redirect_path_for(@section_contact_person.section), notice: t(".success")
    end

    def search
      authorize [:adm, SectionContactPerson], :search?
      @users = params[:search].to_s.length >= 2 ? User.search(params[:search]).limit(4) : User.none
    end

    private

      def load_section_contact_person
        @section_contact_person = SectionContactPerson.find(params[:id])
        authorize [:adm, @section_contact_person]
      end

      def section_contact_person_params
        params.require(:section_contact_person).permit(:user_id, :section, :role, :email, :phone, :position)
      end

      def redirect_path_for(section)
        helper_name = SECTION_REDIRECTS[section]
        helper_name ? send(helper_name) : adm_root_path
      end

      def back_url
        redirect_path_for(@section_contact_person&.section)
      end

      def form_breadcrumbs
        section = @section_contact_person.section
        [
          { name: t("adm.section_settings.sections.#{section}"), url: redirect_path_for(section), icon: "widgets" },
          { name: t("adm.section_settings.contact_people.title") }
        ]
      end
  end
end
