Rails.application.routes.draw do
  resources :bonuses
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html


  root "home#home"

  resources :vacations, except: :show
  resources :holidays, except: [:show, :new] do
    collection do
      post 'generate/:year', to: 'holidays#generate', as: :generate
    end
  end
  resources :standard_charge_notes, only: [:index, :create, :destroy]
  shallow do
    resources :employees do
      resources :children
      resources :charges, except: [:edit, :update, :show]
      resources :vacations, except: :show
      resources :payslips, only: [ :index, :show ]
    end
  end

  resources 'payslips', only: [ :index, :show ]

  # Payslips (temp routes)
  post 'payslips/process', to: 'payslips#process_employee'
  post 'payslips/process_complete', to: 'payslips#process_employee_complete'

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
  get 'charges', to: 'mock#charges'
  get 'hours/edit', to: 'mock#hours_edit'
  get 'reports', to: 'mock#reports'
end
