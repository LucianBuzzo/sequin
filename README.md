<div align="center">
  <img width="200" height="200" src="https://raw.githubusercontent.com/LucianBuzzo/sequin/master/sequin.png">
  <br>
  <br>

![GitHub release (latest by date)](https://img.shields.io/github/v/release/lucianbuzzo/sequin)
![GitHub last commit](https://img.shields.io/github/last-commit/lucianbuzzo/sequin)
![Master](https://github.com/github/docs/actions/workflows/unit.yml/badge.svg?branch=master)

  <p>
  Sequin is a cryptocurrency implemented in [Crystal][crystal].
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

- [x] Add automated versioning
- [x] Block mining
- [x] Add development guide
- [x] Add automated testing
- [x] Add test harness
- [x] Transactions
- [ ] Transaction signing
- [ ] Rest API
- [ ] Node discovery
- [ ] Consensus
- [ ] Chain recovery
- [ ] Security hardening
- [ ] Lottery
- [ ] Coin burn (ala pancakeswap)
- [ ] User interface
- [ ] Open app on balena

[crystal]:https://crystal-lang.org/
