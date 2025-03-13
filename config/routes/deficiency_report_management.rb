namespace :deficiency_report_management do
  root to: "deficiency_reports#index"

  resources :settings, only: :index

  resources :deficiency_reports, except: [:new, :create] do
    resources :audits, only: :show, controller: "deficiency_report_audits"
    resources :milestones, controller: "deficiency_report_milestones"
    resources :progress_bars, except: :show, controller: "deficiency_report_progress_bars"
    member do
      get :audits
      patch :accept
      patch :toggle_image
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

  resources :categories, only: %i[index new create edit update destroy] do
    collection do
      post "order_categories"
    end
  end

  resources :official_answer_templates, except: :show

  resources :areas, except: :show do
    collection do
      post "order_areas"
    end
  end

  resources :officer_groups, except: :show
  resources :districts, only: [:index, :edit, :update]

  resources :memos, only: %i[create] do
    member do
      post :send_notification
    end
  end
end
