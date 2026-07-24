require "rake/testtask"

# Tiered test tasks for the reports (app/reports/*, app/views/reports/*):
#
#   rake test:reports:unit         report logic/methods, no DB query
#   rake test:reports:integration  execute the report SQL against the DB
#   rake test:reports:e2e          render the .thinreports view to a PDF
#   rake test:reports:all          all three tiers
#
# These are focused subsets; `rails test` still runs everything under
# test/ (including all of the above) as usual.
namespace :test do
  namespace :reports do
    Rake::TestTask.new(:unit) do |t|
      t.libs << "test"
      t.test_files = FileList["test/reports/unit/**/*_test.rb"]
      t.warning = false
    end

    Rake::TestTask.new(:integration) do |t|
      t.libs << "test"
      t.test_files = FileList["test/reports/integration/**/*_test.rb"]
      t.warning = false
    end

    Rake::TestTask.new(:e2e) do |t|
      t.libs << "test"
      t.test_files = FileList["test/reports/e2e/**/*_test.rb"]
      t.warning = false
    end

    desc "Run all report tests (unit + integration + e2e)"
    Rake::TestTask.new(:all) do |t|
      t.libs << "test"
      t.test_files = FileList["test/reports/**/*_test.rb"]
      t.warning = false
    end
  end
end
