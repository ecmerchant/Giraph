require 'csv'
bom = "\uFEFF"
CSV.generate(bom) do |csv|
  header = [
    "注文日",
    "Order ID",
    "SKU",
    "売上[$]",
    "手数料[$]",
    "為替[円/$]",
    "仕入値[円]",
    "送料[円]",
    "利益[円]",
    "ROI[%]"
  ]

  pos = 0
  range = 100

  csv << header
  loop do
    results = @orders.offset(pos).limit(range).pluck(
      :order_date,
      :order_id,
      :sku,
      :sales,
      :amazon_fee,
      :ex_rate,
      :cost_price,
      :listing_shipping,
      :profit,
      :roi
    )
    break if results.empty?
    results.each do |result|
      csv << result
    end
    results = nil
    pos += range
  end
end
