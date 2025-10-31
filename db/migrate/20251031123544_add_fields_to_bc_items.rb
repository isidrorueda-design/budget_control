class AddFieldsToBcItems < ActiveRecord::Migration[5.2]
  def change
    add_column :bc_items, :unit, :string
    add_column :bc_items, :unit_price, :decimal, precision: 10, scale: 2
    add_column :bc_items, :quantity, :decimal, precision: 10, scale: 2
  end
end
