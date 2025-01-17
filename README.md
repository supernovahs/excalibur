# Excalibur

Excalibur is an Ethereum Application Client optimized for speed and security.

## Use case
Use Excalibur to directly interface with applications deployed on EVM networks.

## Ethereum Application Client

### Problem
Interacting with smart contracts that are deployed on Ethereum and other EVM blockchains is delivered through a fragmented technology stack written in multiple different languages and often hosted in a browser website. This creates centralization, expands attack vectors, and negatively impacts performance.

### Solution
Excalibur is an Ethereum Application Client which vertically integrates all components of the EVM tech stack into one package. This enables end users to directly interface with even the lowest parts of the stack, e.g. Ethereum nodes. It also empowers existing capabilities to be more performant, for example, transaction simulation, fetching blockchain data, and transaction execution.

### Journal
You will need to `cargo install mdbook` and `cargo install mdbook-katex` to be able to render the journal properly.
To see the journal you can run from the root directory:
```bash
mdbook serve journal
```
and visit `localhost:3000` in your browser.

## Dependencies
- [Anvil](https://github.com/foundry-rs/foundry) is installed and available in `$PATH`.
- [Forge](https://github.com/foundry-rs/foundry) is installed and available in `$PATH`.
- [Arbiter](https://github.com/primitivefinance/arbiter) is installed and available in `$PATH`.

## Installation part 1: rust

```bash
cargo install --path .
```

## Installation part 2: foundry dependencies, artifacts, and bindings

There is one (let's keep it that way!) dependency: primitivefinance/solstat. This has its own dependencies forge-std and solmate, which we also use. Make sure to use forge to install this prior to building the contracts.

```bash
make
```

## Run

### Application
```bash
cargo run ui
```

### Simulation
```bash
cargo run simulate <config>
```

## Project layout
- assets/ - Static assets used in application
- benches/ - Benchmarks for all crates
- bin - CLI entrypoint
- configs/ - Simulation configurations
- crates/ - All rust code
- journal/ - Team knowledge corpus
- lib/ - Git submodule dependencies
- src/ - Smart contracts

## Architecture

Excalibur is a full-stack client for interacting with EVM blockchain applications in simulated and live environments.
- 100% written in Rust.
- User interface is built using the [iced](https://github.com/iced-rs/iced) framework.
- Excalibur's simulation engine is powered by [Arbiter](https://github.com/primitivefinance/arbiter), a performant & open-source EVM simulation framework.
- Excalibur implements its own simulation management framework and communicates with Arbiter via an arbiter client. When combined, Excalibur is capable of running parallelized agent based simulations for any integrated ABS module.
- Excalibur integrates various RPC client connections to enable live transaction execution in the application, including a "dev" client that runs Anvil instances.


## UI Components

Excalibur only has a few underlying primitives that can be chosen from to construct color and text.

![](./assets/excalibur_ui_components.png)

## Future

Excalibur's fully vertical application design makes it easy to plug in more components of the Ethereum stack. In the future, Excalibur will be able to easily connect to local RETH nodes.

## Documentation 

if you have mdbook installed you can run 
    
    ```bash
    mdbook serve
    ```
from the root of the repository to see our living documentation of our though processes and development. This is by no means proffesional or complete more so a compilation of the teams notes and journal throughout the development process.

[Telegram](https://t.me/+9wgBbuoh79M0ZjZh)

## Disclaimer
> Excalibur is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no event shall the authors or copyright holders be liable for any claim, damages or other liability, whether in an action of contract, tort or otherwise, arising from, out of or in connection with the software or the use or other dealings in the software.