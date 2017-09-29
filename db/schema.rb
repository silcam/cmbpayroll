# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20170929132637) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "audits", force: :cascade do |t|
    t.integer "auditable_id"
    t.string "auditable_type"
    t.integer "associated_id"
    t.string "associated_type"
    t.integer "user_id"
    t.string "user_type"
    t.string "username"
    t.string "action"
    t.jsonb "audited_changes"
    t.integer "version", default: 0
    t.string "comment"
    t.string "remote_address"
    t.string "request_uuid"
    t.datetime "created_at"
    t.index ["associated_id", "associated_type"], name: "associated_index"
    t.index ["auditable_id", "auditable_type"], name: "auditable_index"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["request_uuid"], name: "index_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "user_index"
  end

  create_table "bonuses", force: :cascade do |t|
    t.string "name"
    t.decimal "quantity"
    t.integer "bonus_type"
    t.string "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "bonuses_employees", id: false, force: :cascade do |t|
    t.bigint "employee_id"
    t.bigint "bonus_id"
    t.index ["bonus_id"], name: "index_bonuses_employees_on_bonus_id"
    t.index ["employee_id", "bonus_id"], name: "index_bonuses_employees_on_employee_id_and_bonus_id", unique: true
    t.index ["employee_id"], name: "index_bonuses_employees_on_employee_id"
  end

  create_table "charges", force: :cascade do |t|
    t.integer "amount"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "employee_id"
    t.string "note"
    t.date "date"
    t.index ["employee_id"], name: "index_charges_on_employee_id"
  end

  create_table "children", force: :cascade do |t|
    t.boolean "is_student", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "person_id"
    t.bigint "parent_id"
    t.index ["parent_id"], name: "index_children_on_parent_id"
    t.index ["person_id"], name: "index_children_on_person_id"
  end

  create_table "deductions", force: :cascade do |t|
    t.string "note"
    t.decimal "amount"
    t.datetime "date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "payslip_id"
    t.index ["payslip_id"], name: "index_deductions_on_payslip_id"
  end

  create_table "departments", force: :cascade do |t|
    t.string "name"
    t.string "description"
    t.string "account"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "earnings", force: :cascade do |t|
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "payslip_id"
    t.decimal "hours"
    t.decimal "rate"
    t.decimal "amount"
    t.decimal "percentage"
    t.boolean "overtime", default: false, null: false
    t.index ["payslip_id"], name: "index_earnings_on_payslip_id"
  end

  create_table "employees", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
    t.string "cnps"
    t.string "dipe"
    t.datetime "contract_start"
    t.datetime "contract_end"
    t.integer "category"
    t.integer "echelon"
    t.integer "wage_scale"
    t.integer "wage_period"
    t.datetime "last_raise_date"
    t.float "taxable_percentage"
    t.integer "transportation"
    t.integer "employment_status"
    t.integer "marital_status"
    t.integer "hours_day"
    t.integer "days_week"
    t.integer "wage"
    t.bigint "person_id"
    t.bigint "supervisor_id"
    t.bigint "department_id"
    t.boolean "amical", default: false, null: false
    t.boolean "union", default: false, null: false
    t.index ["department_id"], name: "index_employees_on_department_id"
    t.index ["person_id"], name: "index_employees_on_person_id"
    t.index ["supervisor_id"], name: "index_employees_on_supervisor_id"
  end

  create_table "holidays", force: :cascade do |t|
    t.string "name"
    t.date "date"
    t.date "observed"
    t.date "bridge"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "payslips", force: :cascade do |t|
    t.datetime "payslip_date"
    t.datetime "last_processed"
    t.decimal "gross_pay"
    t.decimal "net_pay"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "employee_id"
    t.integer "period_month"
    t.integer "period_year"
    t.decimal "vacation_earned"
    t.decimal "vacation_balance"
    t.date "last_vacation_start"
    t.date "last_vacation_end"
    t.index ["employee_id"], name: "index_payslips_on_employee_id"
  end

  create_table "people", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.integer "gender"
    t.date "birth_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "standard_charge_notes", force: :cascade do |t|
    t.string "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "supervisors", force: :cascade do |t|
    t.bigint "person_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id"], name: "index_supervisors_on_person_id"
  end

  create_table "system_variables", force: :cascade do |t|
    t.string "key"
    t.float "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "username"
    t.bigint "person_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "password_digest"
    t.integer "language", default: 0
    t.index ["person_id"], name: "index_users_on_person_id"
  end

  create_table "vacations", force: :cascade do |t|
    t.bigint "employee_id"
    t.date "start_date"
    t.date "end_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_vacations_on_employee_id"
  end

  create_table "wages", force: :cascade do |t|
    t.integer "category", null: false
    t.string "echelon", null: false
    t.integer "echelonalt", null: false
    t.integer "basewage", null: false
    t.integer "basewageb", null: false
    t.integer "basewagec", null: false
    t.integer "basewaged", null: false
    t.integer "basewagee", null: false
    t.index ["category", "echelon", "echelonalt"], name: "index_wages_on_category_and_echelon_and_echelonalt", unique: true
    t.index ["echelon"], name: "index_wages_on_echelon"
  end

  create_table "work_hours", force: :cascade do |t|
    t.bigint "employee_id"
    t.date "date"
    t.float "hours"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "department_id"
    t.index ["department_id"], name: "index_work_hours_on_department_id"
    t.index ["employee_id"], name: "index_work_hours_on_employee_id"
  end

  add_foreign_key "earnings", "payslips"
  add_foreign_key "employees", "departments"
  add_foreign_key "payslips", "employees"
end
