class Admin::ProjektArgumentsController < Admin::BaseController
  include ProjektArgumentAdminActions
  include EmbeddedAuth
end
