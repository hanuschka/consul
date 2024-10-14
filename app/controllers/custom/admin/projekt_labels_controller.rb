class Admin::ProjektLabelsController < Admin::BaseController
  include ProjektLabelActions
  include EmbeddedAuth
end
