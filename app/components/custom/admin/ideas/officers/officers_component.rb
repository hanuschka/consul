class Admin::Ideas::Officers::OfficersComponent < ApplicationComponent
  attr_reader :officers, :options

  def initialize(officers, **options)
    @officers = officers
    @options = options
  end

  private

    def add_user_path(officer)
      {
        controller: "admin/ideas/officers",
        action: :create,
        user_id: officer.user_id
      }
    end
end
