class AccessPolicy
  include AccessGranted::Policy

  def configure
    # Access Policy file for CMB EPS
    #
    # For more details on how to manage this file, check the README at
    #
    # https://github.com/chaps-io/access-granted/blob/master/README.md
    #
    # Remember, roles inherit from less important roles, so:
    # - :admin has permissions defined in :member, :guest and himself
    # - :member has permissions from :guest and himself
    # - :guest has only its own permissions since it's the first role.
    #
    #
    # BEGIN CMB EPS ROLES
    # ===================
    #
    # The most important role should be at the top.
    # In this case an administrator.
    role :admin, proc { |user| user.admin?} do
      # permissions go here

      # can do everything.
      can :read, AdminController # see admin pages
      can :read, ReportsController # see reports

      can :create, User
      can :read, User
      can :update, User
      can :destroy, User
      can :managerole, User

      can :create, Employee
      can :read, Employee
      can :update, Employee
      can :destroy, Employee
      can :admin, Employee

      can :read, Payslip
      can :update, Payslip

      can :read, Wage
      can :update, Wage

      can :create, Bonus
      can :read, Bonus
      can :update, Bonus
      can :destroy, Bonus

      can :create, Charge
      can :read, Charge
      can :update, Charge
      can :destroy, Charge

      can :create, Department
      can :read, Department
      can :update, Department
      can :destroy, Department

      can :create, Loan
      can :read, Loan
      can :update, Loan
      can :destroy, Loan

      can :create, LoanPayment
      can :read, LoanPayment
      can :update, LoanPayment
      can :destroy, LoanPayment

      can :create, StandardChargeNote
      can :read, StandardChargeNote
      can :update, StandardChargeNote
      can :destroy, StandardChargeNote

      can :create, Holiday
      can :read, Holiday
      can :update, Holiday
      can :destroy, Holiday

      can :create, Child
      can :read, Child
      can :update, Child
      can :destroy, Child

      can :create, Supervisor
      can :read, Supervisor
      can :update, Supervisor
      can :destroy, Supervisor

      can :create, WorkLoan
      can :read, WorkLoan
      can :update, WorkLoan
      can :destroy, WorkLoan

      can :create, WorkHour
      can :read, WorkHour
      can :update, WorkHour
      can :destroy, WorkHour

      can :create, Vacation
      can :read, Vacation
      can :update, Vacation
      can :destroy, Vacation
    end

    # More privileged role, in this case supervisors
    # are able to see employees that they supervise
    # and perform limited administration on these
    # employees.
    role :supervisor, proc { |user| user.supervisor?} do
      # permissions go here

      # TODO, multi-level supervisors
      can :read, Employee do |employee, user|
        # can read if this user is the employee's supervisor or if self
        employee.supervisor.person.id == user.person.id or
            employee.person.id == user.person.id
      end

      # TODO, multi-level supervisors
      can :update, Employee do |employee, user|
        # can update if user is employee's supervisor
        employee.supervisor.person.id == user.person.id
      end

      # can read self
      can :read, User do |user, cur_user|
        user == cur_user
      end

      # can update self
      can :update, User do |user, cur_user|
        user == cur_user
      end

      can :read, Payslip do |payslip, user|
        # can read if personal payslip
        payslip.employee.supervisor.person.id == user.person.id
      end

      can :read, Charge do |charge, user|
        # can read if charge is for reporting employee
        charge.employee.supervisor.person.id == user.person.id
      end

      can :read, Loan do |loan, user|
        # can read if loan is for reporting employee
        loan.employee.supervisor.person.id == user.person.id
      end

      can :read, LoanPayment do |loan_payment, user|
        # can read if loan_payment is for reporting employee
        loan_payment.loan.employee.supervisor.person.id == user.person.id
      end

      can :read, WorkHour do |work_hour, user|
        # can read if work_hour is for reporting employee
        work_hour.employee.supervisor.person.id == user.person.id
      end
    end

    # An employee with user role can perform limited
    # operations on herself (read, mostly).
    role :self, proc { |user| user.user?} do
      # permissions go here

      can :read, Employee do |employee, user|
        # can read if looking at self
        employee.person.id == user.person.id
      end

      # can read self
      can :read, User do |user, cur_user|
        user == cur_user
      end

      # can update self
      can :update, User do |user, cur_user|
        user == cur_user
      end

      can :read, Payslip do |payslip, user|
        # can read if personal payslip
        payslip.employee.person.id == user.person.id
      end

      can :read, Charge do |charge, user|
        # can read if looking at self
        charge.employee.person.id == user.person.id
      end

      can :read, Loan do |loan, user|
        # can read if looking at self
        loan.employee.person.id == user.person.id
      end

      can :read, LoanPayment do |loan_payment, user|
        # can read if looking at self
        loan_payment.loan.employee.person.id == user.person.id
      end

      can :read, Child do |child, user|
        # can read if looking at own child
        child.parent.id == user.person.id
      end

      can :read, WorkHour do |work_hour, user|
        # can read if looking at own work_hour
        work_hour.employee.person.id == user.person.id
      end
    end

    # A user with no role.  In the case of EPS, this
    # user can do nothing
    role :guest do
    end

    # ===================
  end
end
