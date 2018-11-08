require 'csv'
bom = "\uFEFF"
CSV.generate(bom) do |csv|
  header = [
    "ASIN",
    "SKU",
    "日本価格[円]",
    "日本ポイント",
    "仕入値[円]",
    "奥行[cm]",
    "幅[cm]",
    "高さ[cm]",
    "重量[kg]",
    "梱包重量[kg]",
    "アメリカ最安値[$]",
    "アメリカ最安値の送料[$]",
    "最大ROI[%]",
    "アメリカ販売価格[$]",
    "AmazonReferralFee[$]",
    "販売手数料[%]",
    "VariableClosingFee[$]",
    "送料[円]",
    "発送代行手数料[円]",
    "為替レート[円/$]",
    "Payoneer手数料[%]",
    "計算為替[円/$]",
    "利益[円]",
    "最低販売価格[$]",
    "ROI[%]",
    "国内在庫",
    "出品中"
  ]


  shift = ENV['DL_SHIFT'].to_i
  range_max = ENV['DL_RANGE'].to_i

  pos = shift
  range = 20000

  csv << header
  loop do
    results = @products.offset(pos).limit(range).pluck(
      :asin,
      :sku,
      :jp_price,
      :jp_point,
      :cost_price,
      :size_length,
      :size_width,
      :size_height,
      :size_weight,
      :shipping_weight,
      :us_price,
      :us_shipping,
      :max_roi,
      :us_listing_price,
      :referral_fee,
      :referral_fee_rate,
      :variable_closing_fee,
      :listing_shipping,
      :delivery_fee,
      :exchange_rate,
      :payoneer_fee,
      :calc_ex_rate,
      :profit,
      :minimum_listing_price,
      :roi,
      :on_sale,
      :listing
    )
    break if results.empty?
    results.each do |result|
      csv << result
    end
    results = nil 
    pos += range
    break if pos > range_max
  end
end
