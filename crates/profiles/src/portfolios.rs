//! Main serialized data structure for Portfolios.

use serde::{Deserialize, Serialize};

use super::{coins::StaticCoin, *};

/// A data type for a target value, with a label.
/// E.g. 10.00% weight, 20.00% volatility, etc.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Targetable {
    Weight(f64),
    Volatility(f64),
    Return(f64),
}

impl Default for Targetable {
    fn default() -> Self {
        Targetable::Weight(1.0)
    }
}

/// A data type for a position in a portfolio.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Position {
    pub asset: StaticCoin,
    pub cost: Option<f64>,
    pub balance: Option<f64>,
    pub targets: Option<Vec<Targetable>>,
}

impl Position {
    pub fn new(asset: StaticCoin, cost: Option<f64>, balance: Option<f64>) -> Self {
        Self {
            asset,
            cost,
            balance,
            targets: None,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Portfolio {
    pub name: String,
    pub ticker: String,
    pub positions: Vec<Position>,
    pub bench_mark: Option<f64>,
}

impl Portfolio {
    pub fn new(name: String, ticker: String, positions: Vec<Position>) -> Self {
        Self {
            name,
            ticker,
            positions,
            bench_mark: None,
        }
    }

    pub fn add_position(&mut self, position: Position) {
        self.positions.push(position);
    }

    pub fn remove_position(&mut self, index: usize) {
        self.positions.remove(index);
    }

    pub fn update_position(&mut self, index: usize, position: Position) {
        self.positions[index] = position;
    }

    pub fn update_position_asset(&mut self, index: usize, asset: StaticCoin) {
        self.positions[index].asset = asset;
    }

    pub fn update_position_cost(&mut self, index: usize, cost: Option<f64>) {
        self.positions[index].cost = cost;
    }

    pub fn update_position_balance(&mut self, index: usize, balance: Option<f64>) {
        self.positions[index].balance = balance;
    }

    pub fn update_position_targets(&mut self, index: usize, targets: Option<Vec<Targetable>>) {
        self.positions[index].targets = targets;
    }
}

const PORTFOLIO_EXTENSION: &'static str = "json";
const PORTFOLIO_SUFFIX: &'static str = "portfolio";

impl Saveable for Portfolio {
    const EXTENSION: &'static str = PORTFOLIO_EXTENSION;
    const SUFFIX: &'static str = PORTFOLIO_SUFFIX;

    fn prefix(&self) -> Option<String> {
        Some(self.name.clone())
    }

    /// Overwrites the default dir (just config_dir) with a new directory
    /// "portfolios".
    fn dir() -> PathBuf {
        // If portfolios directory does not exist, create it.
        let dir = Self::config_dir().join("portfolios");
        if !dir.exists() {
            std::fs::create_dir_all(&dir).expect("Could not create portfolios directory.");
        }

        dir
    }

    fn create_new(name: Option<String>) -> Result<Self> {
        let name = name.unwrap_or_else(|| "default".to_string());
        let path = Self::dir().join(format!("{}.{}.{}", name, Self::SUFFIX, Self::EXTENSION));
        let file = File::create(path)?;

        let mut portfolio = Self::default();
        portfolio.name = name;

        serde_json::to_writer_pretty(file, &portfolio)?;
        Ok(portfolio)
    }
}

#[cfg(test)]
mod tests {
    use std::path::Path;

    use super::*;

    #[test]
    fn test_portfolio_create() {
        let result = Portfolio::create_new(Some("test".to_string()));
        assert!(result.is_ok());
        assert!(Path::new(&result.unwrap().file_path()).exists());
    }

    #[test]
    fn test_portfolio_load() {
        let name = Some("test".to_string());
        let file_path = Portfolio::file_path_with_name(name.unwrap());
        let result = Portfolio::load(Some(file_path));
        println!("Loaded portfolio: {:?}", result);
        assert!(result.is_ok());
        assert_eq!("test".to_string(), result.unwrap().name);
    }
}
