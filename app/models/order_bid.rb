# encoding: UTF-8
# frozen_string_literal: true

class OrderBid < Order
  has_many :trades, foreign_key: :bid_id
  scope :matching_rule, -> { order(price: :desc, created_at: :asc) }

  validates :price, presence: true, if: :is_limit_order?
  validates :price,
            numericality: { less_than_or_equal_to: ->(order){ order.market.max_bid_price }},
            if: ->(order){ order.ord_type == 'limit' && order.market.max_bid_price.nonzero? }

  validates :origin_volume,
            presence: true,
            numericality: { greater_than_or_equal_to: ->(order){ order.market.min_bid_amount }}

  # @deprecated
  def hold_account
    member.get_account(bid)
  end

  # @deprecated
  def hold_account!
    Account.lock.find_by!(member_id: member_id, currency_id: bid)
  end

  def expect_account
    member.get_account(ask)
  end

  def expect_account!
    Account.lock.find_by!(member_id: member_id, currency_id: ask)
  end

  def avg_price
    return ::Trade::ZERO if funds_received.zero?
    config.fix_number_precision(:bid, funds_used / funds_received)
  end

  def currency
    Currency.find(bid)
  end

  LOCKING_BUFFER_FACTOR = '1.1'.to_d
  def compute_locked(trigger_price)
    if is_advanced? && trigger_price.blank?
      raise ArgumentError, "The variable trigger_price is not set."
    end

    case ord_type
    when is_limit?
      price*volume
    when is_market?
      funds = estimate_required_funds(Global[market_id].asks, trigger_price) {|p, v| p*v }
      funds*LOCKING_BUFFER_FACTOR
    end
  end

end

# == Schema Information
# Schema version: 20190213104708
#
# Table name: orders
#
#  id             :integer          not null, primary key
#  bid            :string(10)       not null
#  ask            :string(10)       not null
#  market_id      :string(20)       not null
#  price          :decimal(32, 16)
#  volume         :decimal(32, 16)  not null
#  origin_volume  :decimal(32, 16)  not null
#  fee            :decimal(32, 16)  default(0.0), not null
#  state          :integer          not null
#  type           :string(8)        not null
#  member_id      :integer          not null
#  ord_type       :string(30)       not null
#  locked         :decimal(32, 16)  default(0.0), not null
#  origin_locked  :decimal(32, 16)  default(0.0), not null
#  funds_received :decimal(32, 16)  default(0.0)
#  trades_count   :integer          default(0), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_orders_on_member_id                     (member_id)
#  index_orders_on_state                         (state)
#  index_orders_on_type_and_market_id            (type,market_id)
#  index_orders_on_type_and_member_id            (type,member_id)
#  index_orders_on_type_and_state_and_market_id  (type,state,market_id)
#  index_orders_on_type_and_state_and_member_id  (type,state,member_id)
#  index_orders_on_updated_at                    (updated_at)
#
