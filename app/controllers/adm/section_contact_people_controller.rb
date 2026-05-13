module Adm
  class SectionContactPeopleController < Adm::BaseController
    before_action :load_section_contact_person, only: [:edit, :update, :destroy]

    helper_method :back_url, :adm_section

    def new
      @section_contact_person = SectionContactPerson.new(section: adm_section)
      authorize [:adm, @section_contact_person]
      @breadcrumbs = form_breadcrumbs
    end

    def create
      @section_contact_person = SectionContactPerson.new(section_contact_person_params.merge(section: adm_section))
      authorize [:adm, @section_contact_person]

      if @section_contact_person.save
        redirect_to section_contact_persons_path, notice: t(".success")
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
        redirect_to section_contact_persons_path, notice: t(".success")
      else
        @breadcrumbs = form_breadcrumbs
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @section_contact_person.destroy!
      redirect_to section_contact_persons_path, notice: t(".success")
    end

    def search
      authorize [:adm, SectionContactPerson], :search?
      @users = params[:search].to_s.length >= 2 ? User.search(params[:search]).limit(4) : User.none
    end

    private

      def adm_section
        params[:adm_section]
      end

      def load_section_contact_person
        @section_contact_person = SectionContactPerson.find(params[:id])
        authorize [:adm, @section_contact_person]
      end

      def section_contact_person_params
        params.require(:section_contact_person).permit(:user_id, :role, :email, :phone, :position)
      end

      def section_contact_persons_path
        send("contact_persons_adm_#{adm_section}_settings_path")
      end

      def back_url
        section_contact_persons_path
      end

      def form_breadcrumbs
        [
          { name: t("adm.section_settings.sections.#{adm_section}"),
            url: send("adm_#{adm_section}_settings_path"),
            icon: "settings" },
          { name: t("adm.section_settings.contact_people.title"),
            url: section_contact_persons_path }
        ]
      end
  end
end
