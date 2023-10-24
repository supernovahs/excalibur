use super::{errors::SimulationError, *};
use crate::{
    agents::{
        arbitrageur::Arbitrageur, liquidity_provider::LiquidityProvider,
        price_changer::PriceChanger, token_admin::TokenAdmin, weight_changer::WeightChanger,
    },
    settings::SimulationConfig,
};

pub async fn run(config: SimulationConfig<Direct>) -> Result<(), SimulationError> {
    todo!();
}
