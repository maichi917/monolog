class ConvertPrimaryKeysToUuid < ActiveRecord::Migration[7.1]
  def up
    add_uuid_columns
    copy_foreign_keys_to_uuid_columns
    verify_uuid_columns
    remove_bigint_constraints_and_indexes
    replace_bigint_columns
    add_uuid_constraints_and_indexes
  end

  def down
    raise ActiveRecord::IrreversibleMigration, <<~MESSAGE
      UUID化後に作成されたデータを元の連番IDへ安全に戻すことはできません。
      ロールバックが必要な場合は、マイグレーション適用前のバックアップからDBを復元してください。
    MESSAGE
  end

  private

  def add_uuid_columns
    add_column :users, :id_uuid, :uuid, default: -> { "gen_random_uuid()" }, null: false

    add_column :items, :id_uuid, :uuid, default: -> { "gen_random_uuid()" }, null: false
    add_column :items, :user_id_uuid, :uuid

    add_column :usage_logs, :id_uuid, :uuid, default: -> { "gen_random_uuid()" }, null: false
    add_column :usage_logs, :item_id_uuid, :uuid
    add_column :usage_logs, :user_id_uuid, :uuid

    add_column :active_storage_blobs, :id_uuid, :uuid, default: -> { "gen_random_uuid()" }, null: false

    add_column :active_storage_attachments, :id_uuid, :uuid, default: -> { "gen_random_uuid()" }, null: false
    add_column :active_storage_attachments, :record_id_uuid, :uuid
    add_column :active_storage_attachments, :blob_id_uuid, :uuid

    add_column :active_storage_variant_records, :id_uuid, :uuid, default: -> { "gen_random_uuid()" }, null: false
    add_column :active_storage_variant_records, :blob_id_uuid, :uuid
  end

  def copy_foreign_keys_to_uuid_columns
    execute <<~SQL
      UPDATE items
      SET user_id_uuid = users.id_uuid
      FROM users
      WHERE items.user_id = users.id
    SQL

    execute <<~SQL
      UPDATE usage_logs
      SET item_id_uuid = items.id_uuid
      FROM items
      WHERE usage_logs.item_id = items.id
    SQL

    execute <<~SQL
      UPDATE usage_logs
      SET user_id_uuid = users.id_uuid
      FROM users
      WHERE usage_logs.user_id = users.id
    SQL

    execute <<~SQL
      UPDATE active_storage_attachments
      SET blob_id_uuid = active_storage_blobs.id_uuid
      FROM active_storage_blobs
      WHERE active_storage_attachments.blob_id = active_storage_blobs.id
    SQL

    execute <<~SQL
      UPDATE active_storage_variant_records
      SET blob_id_uuid = active_storage_blobs.id_uuid
      FROM active_storage_blobs
      WHERE active_storage_variant_records.blob_id = active_storage_blobs.id
    SQL

    execute <<~SQL
      UPDATE active_storage_attachments
      SET record_id_uuid = items.id_uuid
      FROM items
      WHERE active_storage_attachments.record_type = 'Item'
        AND active_storage_attachments.record_id = items.id
    SQL

    execute <<~SQL
      UPDATE active_storage_attachments
      SET record_id_uuid = active_storage_variant_records.id_uuid
      FROM active_storage_variant_records
      WHERE active_storage_attachments.record_type = 'ActiveStorage::VariantRecord'
        AND active_storage_attachments.record_id = active_storage_variant_records.id
    SQL
  end

  def verify_uuid_columns
    verify_no_nulls :items, :user_id_uuid
    verify_no_nulls :usage_logs, :item_id_uuid
    verify_no_nulls :usage_logs, :user_id_uuid
    verify_no_nulls :active_storage_attachments, :record_id_uuid
    verify_no_nulls :active_storage_attachments, :blob_id_uuid
    verify_no_nulls :active_storage_variant_records, :blob_id_uuid
  end

  def verify_no_nulls(table, column)
    return unless select_value("SELECT EXISTS (SELECT 1 FROM #{quote_table_name(table)} WHERE #{quote_column_name(column)} IS NULL)")

    raise ActiveRecord::MigrationError, "#{table}.#{column} にUUIDへ変換できないデータがあります"
  end

  def remove_bigint_constraints_and_indexes
    remove_foreign_key :items, :users
    remove_foreign_key :usage_logs, :items
    remove_foreign_key :usage_logs, :users
    remove_foreign_key :active_storage_attachments, :active_storage_blobs, column: :blob_id
    remove_foreign_key :active_storage_variant_records, :active_storage_blobs, column: :blob_id

    remove_index :items, name: :index_items_on_user_id
    remove_index :usage_logs, name: :index_usage_logs_on_item_id_and_finished_at
    remove_index :usage_logs, name: :index_usage_logs_on_item_id
    remove_index :usage_logs, name: :index_usage_logs_on_item_id_where_in_use
    remove_index :usage_logs, name: :index_usage_logs_on_user_id_and_finished_at
    remove_index :usage_logs, name: :index_usage_logs_on_user_id
    remove_index :active_storage_attachments, name: :index_active_storage_attachments_on_blob_id
    remove_index :active_storage_attachments, name: :index_active_storage_attachments_uniqueness
    remove_index :active_storage_variant_records, name: :index_active_storage_variant_records_uniqueness

    %i[
      users
      items
      usage_logs
      active_storage_blobs
      active_storage_attachments
      active_storage_variant_records
    ].each do |table|
      execute "ALTER TABLE #{quote_table_name(table)} DROP CONSTRAINT #{quote_table_name("#{table}_pkey")}"
    end
  end

  def replace_bigint_columns
    remove_column :items, :user_id
    remove_column :usage_logs, :item_id
    remove_column :usage_logs, :user_id
    remove_column :active_storage_attachments, :record_id
    remove_column :active_storage_attachments, :blob_id
    remove_column :active_storage_variant_records, :blob_id

    %i[
      users
      items
      usage_logs
      active_storage_blobs
      active_storage_attachments
      active_storage_variant_records
    ].each do |table|
      remove_column table, :id
      rename_column table, :id_uuid, :id
      execute "ALTER TABLE #{quote_table_name(table)} ADD PRIMARY KEY (id)"
    end

    rename_column :items, :user_id_uuid, :user_id
    rename_column :usage_logs, :item_id_uuid, :item_id
    rename_column :usage_logs, :user_id_uuid, :user_id
    rename_column :active_storage_attachments, :record_id_uuid, :record_id
    rename_column :active_storage_attachments, :blob_id_uuid, :blob_id
    rename_column :active_storage_variant_records, :blob_id_uuid, :blob_id
  end

  def add_uuid_constraints_and_indexes
    change_column_null :items, :user_id, false
    change_column_null :usage_logs, :item_id, false
    change_column_null :usage_logs, :user_id, false
    change_column_null :active_storage_attachments, :record_id, false
    change_column_null :active_storage_attachments, :blob_id, false
    change_column_null :active_storage_variant_records, :blob_id, false

    add_index :items, :user_id
    add_index :usage_logs, [ :item_id, :finished_at ]
    add_index :usage_logs, :item_id
    add_index :usage_logs, :item_id,
              unique: true,
              where: "finished_at IS NULL",
              name: :index_usage_logs_on_item_id_where_in_use
    add_index :usage_logs, [ :user_id, :finished_at ]
    add_index :usage_logs, :user_id
    add_index :active_storage_attachments, :blob_id
    add_index :active_storage_attachments,
              [ :record_type, :record_id, :name, :blob_id ],
              name: :index_active_storage_attachments_uniqueness,
              unique: true
    add_index :active_storage_variant_records,
              [ :blob_id, :variation_digest ],
              name: :index_active_storage_variant_records_uniqueness,
              unique: true

    add_foreign_key :items, :users
    add_foreign_key :usage_logs, :items
    add_foreign_key :usage_logs, :users
    add_foreign_key :active_storage_attachments, :active_storage_blobs, column: :blob_id
    add_foreign_key :active_storage_variant_records, :active_storage_blobs, column: :blob_id
  end
end
