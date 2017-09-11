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

ActiveRecord::Schema.define(version: 20170911112056) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "bonuses", force: :cascade do |t|
    t.string "name"
    t.decimal "quantity"
    t.integer "bonus_type"
    t.string "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "children", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.date "birth_date"
    t.boolean "is_student"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "employee_id"
  end

  create_table "employees", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
    t.string "department"
    t.datetime "birth_date"
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
    t.integer "gender"
    t.integer "marital_status"
    t.integer "hours_day"
    t.integer "days_week"
    t.bigint "child_id"
    t.integer "wage"
    t.index ["child_id"], name: "index_employees_on_child_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.integer "amount"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "employee_id"
    t.index ["employee_id"], name: "index_transactions_on_employee_id"
  end

  create_table "vacations", force: :cascade do |t|
    t.bigint "employee_id"
    t.date "start_date"
    t.date "end_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_vacations_on_employee_id"
  end

  create_table "work_hours", force: :cascade do |t|
    t.bigint "employee_id"
    t.date "date"
    t.float "hours"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_work_hours_on_employee_id"
  end

end
