namespace :deficiency_report_management do
  root to: "deficiency_reports#index"

  resources :categories, only: %i[index new create edit update destroy]
  resources :settings, only: :index
  resources :areas, except: :show

  resources :deficiency_reports, except: [:new, :create] do
    resources :audits, only: :show, controller: "deficiency_report_audits"
    member do
      patch :accept
    end
  end

  resources :officers, only: [:index, :create, :destroy] do
    get :search, on: :collection
  end

  resources :statuses, only: %i[index new create edit update destroy] do
    collection do
      post "order_statuses"
    end
  end
end
