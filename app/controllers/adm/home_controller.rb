module Adm
  class HomeController < Adm::BaseController
    def show
      authorize [:adm, :dashboard]
      @breadcrumbs = [{ name: "Home", url: root_path }]
    end
  end
end
