Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  root "home#home"

  resources :vacations, except: :show
  shallow do
    resources :employees do
      resources :transactions
      resources :work_hours
      resources :vacations, except: :show
    end
  end



  # Session Controller
  get 'login', to: 'sessions#new'
  post 'login', to: 'sessions#create'
  delete 'logout', to: 'sessions#destroy'

  # Mock Controller
  get 'mock', to: "mock#home"
  get 'mock_employees', to: 'mock#employees'
  get 'mock_vacation', to: 'mock#vacation'
  get 'transactions', to: 'mock#transactions'
  get 'hours/edit', to: 'mock#hours_edit'
  get 'reports', to: 'mock#reports'
end
