# ViewComponent 4 no longer inherits from ActionView::Base, so components lose
# the view helpers these gems add there. Components call the cocoon links
# directly, and f.invisible_captcha calls back into the component as its
# template. Kaminari's paginate renders its compiled templates into the view
# object, so components call it through helpers instead.
ActiveSupport.on_load(:view_component) do
  include Cocoon::ViewHelpers
  include InvisibleCaptcha::ViewHelpers
end
