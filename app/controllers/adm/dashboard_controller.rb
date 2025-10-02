module Adm
  class DashboardController < Adm::BaseController
    def show
      authorize [:adm, :dashboard]
    end
  end
end
