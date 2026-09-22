resources :municipal_plans, only: [:index, :show] do
  resources :notices, only: :create, controller: "municipal_plan_notices"
end
