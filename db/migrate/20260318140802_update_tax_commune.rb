class UpdateTaxCommune < ActiveRecord::Migration[5.1]
  def change

    # Changes per accounting
    #
    # Monthly salary Range (FCFA)
    # |                  Annual TDL (FCFA)
    # |                  |      Monthly deduction
    # |                  |      |
    # 0       –  62,000       0      0
    # 62,001  –  75,000   3,000    250
    # 75,001  – 100,000   6,000    500
    # 100,001 – 125,000   9,000    750
    # 125,001 – 150,000  12,000  1,000
    # 150,001 – 200,000  15,000  1,250
    # 200,001 – 250,000  18,000  1,500
    # 250,001 – 300,000  24,000  2,000
    # 300,001 – 500,000  27,000  2,250
    # Above     500,000  30,000  2,500

    # Modify tax table. This cannot be undone
    reversible do |dir|
      dir.up do
        execute "UPDATE taxes SET communal = 0    WHERE grosspay <= 62000"
        execute "UPDATE taxes SET communal = 250  WHERE grosspay  > 62000  AND grosspay <= 75000"
        execute "UPDATE taxes SET communal = 500  WHERE grosspay  > 75000  AND grosspay <= 100000"
        execute "UPDATE taxes SET communal = 750  WHERE grosspay  > 100000 AND grosspay <= 125000"
        execute "UPDATE taxes SET communal = 1000 WHERE grosspay  > 125000 AND grosspay <= 150000"
        execute "UPDATE taxes SET communal = 1200 WHERE grosspay  > 150000 AND grosspay <= 200000"
        execute "UPDATE taxes SET communal = 1500 WHERE grosspay  > 200000 AND grosspay <= 250000"
        execute "UPDATE taxes SET communal = 2000 WHERE grosspay  > 250000 AND grosspay <= 300000"
        execute "UPDATE taxes SET communal = 2250 WHERE grosspay  > 300000 AND grosspay <= 500000"
        execute "UPDATE taxes SET communal = 2500 WHERE grosspay  > 500000"
      end

      dir.down do
        # Do nothing. The data should be updated regardless.
        # So do not throw Irreversible.
      end
    end

  end
end
