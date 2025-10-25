class CreateBudgetControl < ActiveRecord::Migration[6.1]
  def change
    # 1. Directorio de contratistas
    create_table :bc_contractors do |t|
      t.references :project,    null: false, foreign_key: true # Add project_id
      t.string  :name,       null: false, comment: 'Razón social'
      t.string  :manager,    null: false, comment: 'Nombre del responsable'
      t.string  :phone,      null: false
      t.string  :email,      null: false
      t.timestamps
    end
    add_index :bc_contractors, [:project_id, :name], unique: true # Scope by project

    # 2. Catálogo de partidas
    create_table :bc_items do |t|
      t.references :project,    null: false, foreign_key: true # Add project_id
      t.string :code, null: false
      t.string :description
      t.timestamps
    end
    add_index :bc_items, [:project_id, :code], unique: true # Scope by project

    # 3. Contratos
    create_table :bc_contracts do |t|
      t.references :contractor, null: false, foreign_key: {to_table: :bc_contractors}
      t.references :item,       null: false, foreign_key: {to_table: :bc_items}
      t.string  :number,        null: false
      t.text    :works
      t.decimal :amount,        precision: 15, scale: 2, null: false
      t.decimal :additives,     precision: 15, scale: 2, default: 0.0
      t.decimal :deductives,    precision: 15, scale: 2, default: 0.0
      t.decimal :total,         precision: 15, scale: 2
      t.boolean :apply_iva,     default: false
      t.decimal :iva,           precision: 15, scale: 2
      t.decimal :total_with_iva,precision: 15, scale: 2
      t.decimal :advance,       precision: 15, scale: 2, default: 0.0
      t.date    :start_date
      t.date    :end_date
      t.timestamps
      t.references :project,    null: false, foreign_key: true # Add project_id
    end
    add_index :bc_contracts, [:project_id, :number], unique: true # Scope by project
    add_index :bc_contracts, [:contractor_id, :item_id]
    
    # 4. Estimaciones
    create_table :bc_estimates do |t|
      t.references :contractor, null: false, foreign_key: {to_table: :bc_contractors}
      t.references :contract,   null: false, foreign_key: {to_table: :bc_contracts}
      t.string  :estimate_num,  null: false
      t.decimal :estimated,     precision: 15, scale: 2, null: false
      t.decimal :amortized,     precision: 15, scale: 2, default: 0.0
      t.decimal :warranty_fund, precision: 15, scale: 2, default: 0.0
      t.decimal :retentions,    precision: 15, scale: 2, default: 0.0
      t.decimal :deductive,     precision: 15, scale: 2, default: 0.0
      t.decimal :total_estimated, precision: 15, scale: 2
      t.decimal :iva,           precision: 15, scale: 2
      t.decimal :total,         precision: 15, scale: 2
      t.date    :estimate_date
      t.date    :entry_date
      t.timestamps
      t.references :project,    null: false, foreign_key: true # Add project_id
    end
    add_index :bc_estimates, [:contract_id, :estimate_num], unique: true

    # 5. Extender issues para que apunten a estimación (opcional)
    add_column :issues, :bc_estimate_id, :integer
    add_column :issues, :bc_task_cost,   :decimal, precision: 15, scale: 2
  end
end