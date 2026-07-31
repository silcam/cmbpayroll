# Be sure to restart your server when you modify this file.
#
# This file contains migration options to ease your Rails 6.1 upgrade.
#
# Once upgraded flip defaults one by one to migrate to the new default.
#
# Read the Guide for Upgrading Ruby on Rails for more info on each option.

# Support for inversing belongs_to -> has_many Active Record associations.
Rails.application.config.active_record.has_many_inversing = true

# Track Active Storage variants in the database. This app doesn't use Active
# Storage attachments today, so this is currently dormant either way.
Rails.application.config.active_storage.track_variants = true

# Apply random variation to the delay when retrying failed jobs. No
# `retry_on`-using jobs exist in this app yet, dormant either way.
Rails.application.config.active_job.retry_jitter = 0.15

# Stop executing `after_enqueue`/`after_perform` callbacks if
# `before_enqueue`/`before_perform` respectively halts with `throw :abort`.
Rails.application.config.active_job.skip_after_callbacks_if_terminated = true

# Specify cookies SameSite protection level: either :none, :lax, or :strict.
#
# This change is not backwards compatible with earlier Rails versions.
# It's best enabled when your entire app is migrated and stable on 6.1.
# Rails.application.config.action_dispatch.cookies_same_site_protection = :lax

# Generate CSRF tokens that are encoded in URL-safe Base64.
#
# This change is not backwards compatible with earlier Rails versions.
# It's best enabled when your entire app is migrated and stable on 6.1.
# Rails.application.config.action_controller.urlsafe_csrf_tokens = true

# Specify whether `ActiveSupport::TimeZone.utc_to_local` returns a time with an
# UTC offset or a UTC time. Fixes a longstanding DST-transition bug; verified
# via the full test suite (this app is heavily date/period-arithmetic driven).
ActiveSupport.utc_to_local_returns_utc_offset_times = true

# Change the default HTTP status code to `308` when redirecting non-GET/HEAD
# requests to HTTPS in `ActionDispatch::SSL` middleware. 308 (unlike 301)
# preserves the original request method/body, which is strictly safer.
Rails.application.config.action_dispatch.ssl_default_redirect_status = 308

# Use new connection handling API. For most applications this won't have any
# effect. For applications using multiple databases, this new API provides
# support for granular connection swapping. This app has a single database
# per environment (see config/database.yml), so this is a no-op here.
Rails.application.config.active_record.legacy_connection_handling = false

# Make `form_with` generate non-remote forms by default.
#
# One call site relied on the old remote-by-default behavior without saying
# so explicitly: app/views/admin/estimate_pay.html.erb's #estimate-form is
# wired to rails-ujs's `ajax:success`/`ajax:error` events in
# app/assets/javascripts/admin.coffee, which only fire for remote
# (data-remote="true") forms -- flipping this default would have silently
# turned that AJAX estimate widget into a full-page POST-to-JSON navigation,
# with no test coverage to catch it (grepped test/ -- no test references
# "estimate" at all). Fixed by adding `remote: true` explicitly to that one
# form_with call so it keeps working regardless of this global default.
Rails.application.config.action_view.form_with_generates_remote_forms = false

# Set the default queue name for the analysis job to the queue adapter
# default. This app doesn't use Active Storage attachments today.
Rails.application.config.active_storage.queues.analysis = nil

# Set the default queue name for the purge job to the queue adapter default.
Rails.application.config.active_storage.queues.purge = nil

# Set the default queue name for the incineration job to the queue adapter
# default. This app doesn't use Action Mailbox.
Rails.application.config.action_mailbox.queues.incineration = nil

# Set the default queue name for the routing job to the queue adapter default.
Rails.application.config.action_mailbox.queues.routing = nil

# Set the default queue name for the mail deliver job to the queue adapter
# default. No `deliver_later` call sites exist in this app today.
Rails.application.config.action_mailer.deliver_later_queue_name = nil

# Generate a `Link` header that gives a hint to modern browsers about
# preloading assets when using `javascript_include_tag` and `stylesheet_link_tag`.
Rails.application.config.action_view.preload_links_header = true
