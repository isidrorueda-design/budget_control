class CreateBcBaseBudgets < ActiveRecord::Migration[6.1]
  def change
    create_table :bc_base_budgets do |t|
      t.references :project,    null: false, foreign_key: true
      t.references :bc_item,    null: false, foreign_key: true
      t.decimal :budget_amount, precision: 15, scale: 2, null: false, default: 0.0
      t.timestamps
    end
    add_index :bc_base_budgets, [:project_id, :bc_item_id], unique: true, name: 'index_bc_base_budgets_on_project_and_item'
  end
end