class CreateTaxTable < ActiveRecord::Migration[5.1]
  def change
    create_table(:taxes, id: false) do |t|
      t.decimal :grosspay, primary_key: true
      t.decimal :proportional
      t.decimal :ccf
      t.decimal :crtv
      t.decimal :surtax1
      t.decimal :surtax15
      t.decimal :surtax2
      t.decimal :surtax25
      t.decimal :surtax3
      t.decimal :surtax35
      t.decimal :surtax4
      t.decimal :surtax45
      t.decimal :surtax5
      t.decimal :communal
    end
  end
end
