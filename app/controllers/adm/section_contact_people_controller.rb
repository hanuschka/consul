module Adm
  class SectionContactPeopleController < Adm::BaseController
    before_action :load_section_contact_person, only: [:edit, :update, :destroy]

    def index
      authorize [:adm, SectionContactPerson]
      scope = policy_scope([:adm, SectionContactPerson]).includes(:user).order(:section, :position)
      scope = scope.where(section: params[:section]) if params[:section].in?(SectionContactPerson::SECTIONS)
      @pagy, @section_contact_people = pagy(scope)

      @current_section_filter = params[:section]

      @breadcrumbs = [
        { name: t("adm.menu.items.profiles"), icon: "3p" },
        { name: t("adm.section_contact_people.index.title") }
      ]
    end

    def new
      @section_contact_person = SectionContactPerson.new
      authorize [:adm, @section_contact_person]

      @breadcrumbs = form_breadcrumbs
    end

    def create
      @section_contact_person = SectionContactPerson.new(section_contact_person_params)
      authorize [:adm, @section_contact_person]

      if @section_contact_person.save
        redirect_to adm_section_contact_people_path, notice: t(".success")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @breadcrumbs = form_breadcrumbs
    end

    def update
      if @section_contact_person.update(section_contact_person_params)
        redirect_to adm_section_contact_people_path, notice: t(".success")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @section_contact_person.destroy!
      redirect_to adm_section_contact_people_path, notice: t(".success")
    end

    def search
      authorize [:adm, SectionContactPerson], :create?
      @users = params[:search].to_s.length >= 2 ? User.search(params[:search]).limit(4) : User.none
    end

    private

      def load_section_contact_person
        @section_contact_person = SectionContactPerson.find(params[:id])
        authorize [:adm, @section_contact_person]
      end

      def form_breadcrumbs
        [
          { name: t("adm.menu.items.profiles"), icon: "3p" },
          { name: t("adm.section_contact_people.index.title"), url: adm_section_contact_people_path },
          { name: t(".title") }
        ]
      end

      def section_contact_person_params
        params.require(:section_contact_person).permit(:user_id, :section, :role, :email, :phone, :position)
      end
  end
end
