CMB New Payroll System

## Dependencies

* Ruby 2.7.4 (use rbenv)
* Postgres (9.5)
* Bundler

Note: This application was developed on Linux or Mac. It has not been tested for development on Windows, although you will probably be able to make it work.

## Initial Setup

* Install dependencies locally.
* Clone repo
* bundle update
* Create/seed database
* Run tests
* Start server (if desired)

## Database Initialization

Use normal rails commands to create the database. Keep in mind that the database must be seeded with `rails db:seed` after creation and migration. The wages table requires a wages.sql file which is stored on the server. It is not committed to this repo.

## Running Tests

Fro all tests, run `rails test`. This uses minitest.

You can run just the reports tests with:

`rake test:reports:all`

Or individual classes of report tests

`rake test:reports:unit`
`rake test:reports:integration`
`rake test:reports:e2e`

## Reports

Generally the reports output a PDF. Finance's desire was to have the reports be printable. Creation of the PDF reports uses [Thinreports](http://www.thinreports.org) to help organize and create the reports.

You should use the [Thinreports Editor](http://www.thinreports.org/features/editor/) to edit these reports. The reports can be edited in a text editor as well, but it's helpful to use the GUI editor. There are versions for all platforms.

See [`docs/reports/employee-grade-reports.md`](docs/reports/employee-grade-reports.md) for how the CNPS, Employee, and Employee by Department reports resolve an employee's grade to a specific period.

## Branching

Features should be built on a feature branch from the develop branch. When complete and tested, merge into the develop branch.

## Deployment

Production deployment requires merging the develop branch into the master branch and pushing to Github. After this, run `cap production deploy` to deploy to the production server. This requires passwordless SSH to the production server to complete.

## License

This software project is licensed under the MIT License. See LICENSE.md

## Copyright

This software project is Copyright (C) 2018 SIL International. http://www.sil.org/
