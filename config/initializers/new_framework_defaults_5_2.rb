# Be sure to restart your server when you modify this file.
#
# This file contains migration options to ease your Rails 5.2 upgrade.
#
# Once upgraded flip defaults one by one to migrate to the new default.
#
# Read the Guide for Upgrading Ruby on Rails for more info on each option.

# Make Active Record use stable #cache_key alongside new #cache_version method.
# This is needed for recyclable cache keys.
Rails.application.config.active_record.cache_versioning = true

# Use AES-256-GCM authenticated encryption for encrypted cookies.
# Also, embed cookie expiry in signed or encrypted cookies for increased security.
#
# Not backwards compatible with earlier Rails versions in general, but this
# app has no production traffic yet on this branch (still mid-upgrade, not
# deployed), so there are no live sessions/cookies this needs to stay
# compatible with. Existing cookies would be converted on read then written
# with the new scheme regardless.
Rails.application.config.action_dispatch.use_authenticated_cookie_encryption = true

# Use AES-256-GCM authenticated encryption as default cipher for encrypting messages
# instead of AES-256-CBC, when use_authenticated_message_encryption is set to true.
# Same no-live-traffic reasoning as above.
Rails.application.config.active_support.use_authenticated_message_encryption = true

# Add default protection from forgery to ActionController::Base instead of in
# ApplicationController. This app already declares `protect_from_forgery` in
# ApplicationController explicitly, so this is a no-op belt-and-suspenders
# default, not a behavior change.
Rails.application.config.action_controller.default_protect_from_forgery = true

# Store boolean values are in sqlite3 databases as 1 and 0 instead of 't' and
# 'f' after migrating old data. N/A -- this app uses postgresql, not sqlite3.
# Rails.application.config.active_record.sqlite3.represent_boolean_as_integer = true

# Use SHA-1 instead of MD5 to generate non-sensitive digests, such as the ETag
# header. `use_sha1_digests` itself is deprecated as of this Rails version in
# favor of `hash_digest_class` (same effect); using the current API.
Rails.application.config.active_support.hash_digest_class = ::Digest::SHA1

# Make `form_with` generate id attributes for any generated HTML tags.
Rails.application.config.action_view.form_with_generates_ids = true
