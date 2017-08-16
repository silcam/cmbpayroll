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

ActiveRecord::Schema.define(version: 20170816130144) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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
    t.string "category"
    t.string "echelon"
    t.string "wage_scale"
    t.string "wage_period"
    t.datetime "last_raise_date"
    t.float "taxable_percentage"
    t.integer "transportation"
    t.integer "employment_status"
    t.integer "gender"
    t.integer "marital_status"
    t.integer "hours_day"
    t.integer "days_week"
  end

  create_table "transactions", force: :cascade do |t|
    t.integer "amount"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "employee_id"
    t.index ["employee_id"], name: "index_transactions_on_employee_id"
  end

end
