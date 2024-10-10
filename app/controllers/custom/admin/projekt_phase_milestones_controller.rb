class Admin::ProjektPhaseMilestonesController < Admin::BaseController
  include ProjektPhaseMilestoneActions
  include EmbeddedAuth
end
