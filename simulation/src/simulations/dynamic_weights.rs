use super::*;
use crate::{
    agents::{
        arbitrageur::Arbitrageur, block_admin::BlockAdmin, liquidity_provider::LiquidityProvider,
        price_changer::PriceChanger, token_admin::TokenAdmin, weight_changer::WeightChanger,
    },
    settings::SimulationConfig,
};
use arbiter_core::environment::builder::BlockSettings;

pub async fn run(config_path: &str) -> Result<()> {
    let config = SimulationConfig::new(config_path)?;

    let env = EnvironmentBuilder::new()
        .block_settings(BlockSettings::UserControlled)
        .build();
    let mut block_admin = BlockAdmin::new(&env, &config).await?;

    let token_admin = TokenAdmin::new(&env).await?;
    let mut price_changer = PriceChanger::new(&env, &token_admin, &config).await?;
    let weight_changer = WeightChanger::new(
        &env,
        &config,
        price_changer.liquid_exchange.address(),
        token_admin.arbx.address(),
        token_admin.arby.address(),
    )
    .await?;
    let lp = LiquidityProvider::new(&env, &token_admin, weight_changer.g3m.address()).await?;
    let arbitrageur = Arbitrageur::<G3M<RevmMiddleware>>::new(
        &env,
        &token_admin,
        weight_changer.lex.address(),
        weight_changer.g3m.address(),
    )
    .await?;

    lp.add_liquidity(&config).await?;

    // have the loop iterate blcoks and block timestamps
    // draw random # from poisson distribution which determines how long we wait for
    // price to change loop that causes price change -> arbitrageur -> check if
    // weightchanger needs to run

    EventLogger::builder()
        .path("./analysis/test_data")
        .add(price_changer.liquid_exchange.events(), "lex")
        .add(weight_changer.g3m.events(), "g3m")
        .run()?;

    for index in 0..config.trajectory.num_steps {
        println!("index: {}", index);
        let init_price = weight_changer.g3m.get_spot_price().call().await?;
        println!(
            "init price: {}",
            format_ether(init_price).parse::<f64>().unwrap()
        );
        price_changer.update_price().await?;
        arbitrageur.step().await?;
        let new_price = weight_changer.g3m.get_spot_price().call().await?;
        println!(
            "new price: {}",
            format_ether(new_price).parse::<f64>().unwrap()
        );
        block_admin.update_block().await?;
    }

    Ok(())
}
