<div align="center">
  <img width="372" height="110" src="https://raw.githubusercontent.com/LucianBuzzo/sequin/master/sequin.png">
  <br>
  <br>

![GitHub release (latest by date)](https://img.shields.io/github/v/release/lucianbuzzo/sequin)
![GitHub last commit](https://img.shields.io/github/last-commit/lucianbuzzo/sequin)
![Master](https://github.com/lucianbuzzo/sequin/actions/workflows/unit.yml/badge.svg?branch=master)

  <p>
  Sequin is a cryptocurrency implemented in <a href="https://crystal-lang.org/">Crystal</a>.
  </p>
  <br>
  <br>
</div>


## Development

To get started, set up a [balena](https://dashboard.balena-cloud.com/) device in local mode and use `balena push`. This
will run a docker container on the device that executes the test suite, then
sleeps. Saving changes to the project will cause the test suite to be executed
again.

## Tests

To run unit tests locally:

```sh
make test
```

Linting uses [the GitHub super-linter
project](https://github.com/github/super-linter) and can be run locally using
docker with:

```sh
make lint
```

## Todo

### Testing
- [ ] Code coverage https://hannes.kaeufler.net/posts/measuring-code-coverage-in-crystal-with-kcov

### Wallet
- [ ] Wallet mnemonic seed
- [ ] HD wallet
- [ ] Ability to create multiple wallets

### Transactions

- [ ] Move to candidate block coinbase/generation transactions
- [ ] Refactor to use UTXO and input/output transactions

### User interface

- [ ] Login using JWT
- [ ] Wallet generation (linked to mnemonic seed?)

### Rest API

- [x] Basic Auth
- [x] POST transaction
- [x] GET balance
- [x] GET blockchain
- [ ] GET transaction
- [ ] Multi user auth via "login with GitHub"
  https://levelup.gitconnected.com/how-to-implement-login-with-github-in-a-react-app-bd3d704c64fc

### Mining

- [ ] Set mining reward adress

### Hardware

- [ ] Control inkyshot screen

### Decentralization

- [ ] Persistent on-node blockchain storage
  - [ ] Compressed storage format for blockchain
- [x] Node discovery
- [ ] Open app on balena
- [ ] Consensus
- [ ] Chain recovery

### Features

- [ ] Security hardening
- [ ] Lottery
- [ ] Coin burn (ala pancakeswap)

[crystal]:https://crystal-lang.org/
