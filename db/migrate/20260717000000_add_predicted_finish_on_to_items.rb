class AddPredictedFinishOnToItems < ActiveRecord::Migration[7.1]
  def change
    # 使い切り予測日のキャッシュ。使用履歴の変更時に再計算される。予測できない場合はNULL
    add_column :items, :predicted_finish_on, :date
    add_index :items, :predicted_finish_on
  end
end
