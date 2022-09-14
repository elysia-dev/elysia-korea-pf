# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a script that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
GAS_REPORT=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.ts
```

## 대출 정보
- 대출 시작일: 2022-09-08 GMT+0900
- 대출 만기일: 2022-09-07 GMT+0900

## Test
```sh
# BulletBond
yarn hardhat test

# CouponBond
forge test -vv
```

## Verify
Use https://github.com/wighawag/hardhat-deploy#4-hardhat-etherscan-verify.
```sh
yarn hardhat etherscan-verify --network bscTestnet --api-key $BSCSCAN_API_KEY
```
