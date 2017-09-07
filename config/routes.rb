Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html


  root "home#home"

  resources :vacations, except: :show
  shallow do
    resources :employees do
      resources :children
      resources :transactions
      resources :vacations, except: :show
    end
  end

  # Work Hours
  get 'employees/:employee_id/work_hours',      to: 'work_hours#index', as: :employee_work_hours
  get 'employees/:employee_id/work_hours/edit', to: 'work_hours#edit',  as: :edit_employee_work_hours
  post 'employees/:employee_id/work_hours',    to: 'work_hours#update', as: :update_employee_work_hours

  resources :users

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
