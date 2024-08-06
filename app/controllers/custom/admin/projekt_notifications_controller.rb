class Admin::ProjektNotificationsController < Admin::BaseController
  include ProjektNotificationAdminActions
  include EmbeddedAuth
end
