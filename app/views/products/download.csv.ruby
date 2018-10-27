require 'csv'

CSV.generate do |csv|

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
    "国内在庫 出品中"
  ]

  csv << header
  @products.each_with_index do |product, k|
    column_values = [
      product.asin,
      product.sku,
      product.jp_price.to_i,
      product.jp_point.to_i,
      product.cost_price.to_i,
      product.size_length,
      product.size_width,
      product.size_height,
      product.size_weight,
      product.shipping_weight,
      product.us_price,
      product.us_shipping,
      product.max_roi,
      product.us_listing_price,
      product.referral_fee,
      product.referral_fee_rate,
      product.variable_closing_fee,
      product.listing_shipping.to_i,
      product.delivery_fee.to_i,
      product.exchange_rate,
      product.payoneer_fee,
      product.calc_ex_rate,
      product.profit.to_i,
      product.minimum_listing_price,
      product.roi,
      product.on_sale,
      product.listing
    ]
    logger.debug(k)
    csv << column_values
    if k > 500 then break end
  end
end
