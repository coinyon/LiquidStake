from brownie import (LiquidStake, LiquidStakeDAO, LiquidStakeRewards, accounts,
                     interface)


def main():
    deployer = accounts[0]

    hex_contract = interface.IHEX("0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39")
    dao_contract = LiquidStakeDAO.deploy("LiquidStakeDAO", "LSD", {'from': deployer})

    rewards_contract = LiquidStakeRewards.deploy(deployer, hex_contract, hex_contract,
            hex_contract, {'from': deployer}
        )

    liquidstake = LiquidStake.deploy(
            "LiquidStake",
            "LS",
            hex_contract,
            rewards_contract,
            {'from': deployer}
        )
    rewards_contract.setRewardsDistribution(liquidstake)
    rewards_contract.setStakingToken(dao_contract, {'from': deployer})
