resources :municipal_plans, only: [:index, :show] do
  get :archive, on: :collection

  resources :notices, only: :create, controller: "municipal_plan_notices"
end
