class Admin::ProjektLivestreamsController < Admin::BaseController
  include ProjektLivestreamAdminActions
  include EmbeddedAuth
end
