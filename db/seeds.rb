# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

# SEED WAGES
connection = ActiveRecord::Base.connection
connection.tables.each do |table|
  connection.execute("TRUNCATE #{table}") if table == "wages" ||
      table == "taxes" || table == 'dipe_codes' ||
        table == 'category_lookup' || table == 'echelon_lookup'
end

# - IMPORTANT: SEED DATA ONLY
# - DO NOT EXPORT TABLE STRUCTURES
# - DO NOT EXPORT DATA FROM `schema_migrations`

%w[db/wages.sql db/taxtable.sql db/dipes.sql db/lookups.sql].each do |tbl|
  puts "Loading data from #{tbl}"
  sql = File.read(tbl)
  statements = sql.split(/;$/)
  statements.pop  # the last empty statement

  ActiveRecord::Base.transaction do
    statements.each do |statement|
      connection.execute(statement)
    end
  end
end

unless (User.find_by(username: 'admin'))
  admin_user = User.create!(first_name: 'Admin', last_name: 'User',
    username: 'admin', password: 'changeme',
      password_confirmation: 'changeme', language: :en, role: 'admin')
end

charge = StandardChargeNote.find_by(note: Charge::ADVANCE)
Rails.logger.error(charge.inspect)
if (charge.nil?)
  StandardChargeNote.create!(note: Charge::ADVANCE)
end
