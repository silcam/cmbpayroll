source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end


# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '5.1.6.2'
gem 'actionview', '5.1.6.2'
# Use postgres as the database for Active Record
gem 'pg', '~>0.21.0'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.0'
# Bootstrap
gem 'bootstrap-sass', '3.4.1'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'therubyracer', platforms: :ruby
# Use jquery
gem 'jquery-rails', '~>4.3.1'

# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails', '~> 4.2'
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem 'turbolinks', '~> 5'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.5'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 3.0'
# Use ActiveModel has_secure_password
gem 'bcrypt', '~> 3.1.7'

# PDFs
gem 'prawn', '~> 2.1'
gem 'prawn-rails', '~> 0.1.1'
gem 'prawn-table', '~> 0.2.2'

# date picker
gem 'momentjs-rails', '>= 2.9.0'
gem 'bootstrap3-datetimepicker-rails', '~>4.17.47'

# Internationalization
gem 'rails-i18n', '~> 5.0.4'
# User Roles
gem 'access-granted', '~>1.2.0'

# Audit Trail
gem 'audited', '~> 4.5'

# Reports
gem 'thinreports', '~> 0.10.2'
gem 'thinreports-rails', '~> 0.4.0'
gem 'dossier', '~> 2.13', '>= 2.13.1'
gem 'fixy', '~> 0.0.8'

gem 'roman-numerals', '~> 0.3.0'

# Date Validation
# gem 'validates_timeliness', '~>4.0'

# Update verison for security vulnerability
# 2.2.3 is a fixed version
gem 'loofah', '>= 2.2.3'
# 1.0.4 is a fixed version
gem 'rails-html-sanitizer', '~>1.0.4'
# 3.7.2 is a fixed version (CVE-2018-3760)
gem 'sprockets', '~>3.7.2'
# 1.2.2 is a fixed version (CVE-2018-1000544)
# 1.3.0 is a fixed version (CVE-2019-16892)
gem 'rubyzip', '~>1.3.0'
# 1.9.24 is a fixed version (CVE-2018-1000201)
gem 'ffi', '~>1.9.24'
# 2.0.6 is a fixed version
gem 'rack', '~>2.0.8'
# 5.1.6.1 is fixed version (CVE-2018-16476)
gem 'activejob', '>= 5.1.6.1'
# 1.10.4 is fixed (CVE-2019-5477)
gem 'nokogiri', '>= 1.10.4'

group :development, :test do
  # Use Puma as the app server in development
  gem 'puma', '~> 3.7'
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  # Adds support for Capybara system testing and selenium driver
  gem 'minitest-rails-capybara'
  gem 'selenium-webdriver'
  gem 'minitest-reporters'
  # Checks for security holes in the code
  gem 'brakeman', require: false
end

group :development do
  # Capistrano Deployment
  gem 'capistrano'
  gem 'capistrano-rails'
  gem 'capistrano-rbenv'
  gem 'capistrano-passenger'
  # Access an IRB console on exception pages or by using <%= console %> anywhere in the code.
  gem 'web-console', '>= 3.3.0'
  gem 'listen', '>= 3.0.5', '< 3.2'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
# gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]
