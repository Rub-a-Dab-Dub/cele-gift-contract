use alexandria_math::sha256::sha256;

pub fn compute_hash(bid_amount: u256, nonce: felt252) -> u8 {
    let mut data = ArrayTrait::new();
    data.append(bid_amount.low.into());
    data.append(bid_amount.high.into());
    data.append(nonce);

    // Convert data (Array<felt252>) to Array<u8>
    let mut bytes: Array<u8> = ArrayTrait::new();
    let data_len = data.len();
    let mut i = 0;
    while i < data_len {
        let value = *data.at(i);
        // Convert felt252 to u8 (assuming values fit in u8)
        bytes.append(value.try_into().unwrap());
        i += 1;
    }

    let hash_result = sha256(bytes);
    *hash_result.at(0)
}

pub fn calculate_dutch_price(
    start_price: u256, end_price: u256, start_time: u64, end_time: u64, current_time: u64,
) -> u256 {
    if current_time >= end_time {
        return end_price;
    }

    let elapsed_time = current_time - start_time;
    let total_duration = end_time - start_time;
    let price_drop = start_price - end_price;

    let current_drop = (price_drop * elapsed_time.into()) / total_duration.into();
    start_price - current_drop
}
