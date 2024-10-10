class Admin::ProjektEventsController < Admin::BaseController
  include ProjektEventAdminActions
  include EmbeddedAuth
end
